#!/usr/bin/env python3
"""
pg_backup.py
============
Herramienta de backup para PostgreSQL que soporta tres modos:

  logical   → pg_dump   (backup lógico comprimido, restaurable con pg_restore)
  physical  → pg_basebackup (backup físico para PITR, incluye WAL por streaming)
  both      → Ejecuta lógico + físico en secuencia

Uso rápido:
  python pg_backup.py --mode logical
  python pg_backup.py --mode physical
  python pg_backup.py --mode both --host 192.168.1.10 --db mydb

Variables de entorno alternativas a los argumentos:
  PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE
"""

from __future__ import annotations

import argparse
import hashlib
import logging
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional


# ─────────────────────────────────────────────────────────────────────────────
# Configuración de logging
# ─────────────────────────────────────────────────────────────────────────────

LOG_FORMAT = "%(asctime)s [%(levelname)-8s] %(message)s"
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

logging.basicConfig(format=LOG_FORMAT, datefmt=DATE_FORMAT, level=logging.INFO)
logger = logging.getLogger("pg_backup")


# ─────────────────────────────────────────────────────────────────────────────
# Dataclasses de configuración y resultado
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class PgConfig:
    """Parámetros de conexión a PostgreSQL."""
    host:     str = "localhost"
    port:     int = 5432
    user:     str = "ecommerce_user"
    password: str = "ecommerce_pass"
    dbname:   str = "ecommercedb"


@dataclass
class BackupConfig:
    """Parámetros generales del backup."""
    mode:            str  = "logical"        # logical | physical | both
    backup_dir:      Path = Path("/backup")
    retention_days:  int  = 7
    compress_level:  int  = 9                # 0-9
    # Lógico
    logical_format:  str  = "custom"         # custom | plain | tar | directory
    logical_schemas: list = field(default_factory=list)   # [] = todos
    logical_tables:  list = field(default_factory=list)   # [] = todas
    # Físico
    wal_method:      str  = "stream"         # stream | fetch | none
    checkpoint:      str  = "fast"           # fast | spread
    # Operación
    verify:          bool = True
    dry_run:         bool = False
    log_file:        Optional[Path] = None


@dataclass
class BackupResult:
    """Resultado de una operación de backup."""
    mode:        str
    success:     bool
    start_time:  datetime
    end_time:    Optional[datetime]  = None
    path:        Optional[Path]      = None
    size_bytes:  int                 = 0
    checksum:    Optional[str]       = None
    error:       Optional[str]       = None

    @property
    def duration_seconds(self) -> float:
        if self.end_time:
            return (self.end_time - self.start_time).total_seconds()
        return 0.0

    @property
    def size_human(self) -> str:
        for unit in ("B", "KB", "MB", "GB", "TB"):
            if self.size_bytes < 1024:
                return f"{self.size_bytes:.1f} {unit}"
            self.size_bytes /= 1024
        return f"{self.size_bytes:.1f} PB"

    def summary(self) -> str:
        status = "✓ OK" if self.success else "✗ FAIL"
        lines = [
            f"  Modo      : {self.mode}",
            f"  Estado    : {status}",
            f"  Duración  : {self.duration_seconds:.1f}s",
        ]
        if self.path:
            lines.append(f"  Ruta      : {self.path}")
        if self.success:
            lines.append(f"  Tamaño    : {self.size_human}")
        if self.checksum:
            lines.append(f"  SHA-256   : {self.checksum[:16]}…")
        if self.error:
            lines.append(f"  Error     : {self.error}")
        return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# Utilidades
# ─────────────────────────────────────────────────────────────────────────────

def _check_binary(name: str) -> Path:
    """Lanza FileNotFoundError si el binario no está disponible en el PATH."""
    path = shutil.which(name)
    if not path:
        raise FileNotFoundError(
            f"'{name}' no encontrado en PATH. "
            f"Asegúrese de que los binarios de PostgreSQL están instalados."
        )
    return Path(path)


def _build_env(pg: PgConfig) -> dict:
    """Construye el entorno de subproceso con PGPASSWORD si es necesario."""
    env = os.environ.copy()
    if pg.password:
        env["PGPASSWORD"] = pg.password
    return env


def _run(cmd: list[str], env: dict, dry_run: bool = False) -> subprocess.CompletedProcess:
    """Ejecuta un comando externo con logging. En dry_run solo lo imprime."""
    logger.debug("Comando: %s", " ".join(str(c) for c in cmd))
    if dry_run:
        logger.info("[DRY-RUN] %s", " ".join(str(c) for c in cmd))
        # Simular proceso exitoso
        return subprocess.CompletedProcess(cmd, returncode=0, stdout=b"", stderr=b"")

    result = subprocess.run(
        cmd,
        env=env,
        capture_output=True,
        text=True,
    )
    if result.stdout.strip():
        for line in result.stdout.strip().splitlines():
            logger.debug("stdout: %s", line)
    if result.stderr.strip():
        for line in result.stderr.strip().splitlines():
            # pg_dump / pg_basebackup usan stderr para progreso y avisos
            level = logging.WARNING if result.returncode != 0 else logging.DEBUG
            logger.log(level, "stderr: %s", line)
    return result


def _get_size(path: Path) -> int:
    """Devuelve el tamaño en bytes de un fichero o directorio."""
    if path.is_file():
        return path.stat().st_size
    total = 0
    for p in path.rglob("*"):
        if p.is_file():
            total += p.stat().st_size
    return total


def _sha256_file(path: Path) -> str:
    """Calcula el SHA-256 de un fichero."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _sha256_dir(path: Path) -> str:
    """Calcula un SHA-256 combinado de todos los ficheros de un directorio."""
    h = hashlib.sha256()
    for p in sorted(path.rglob("*")):
        if p.is_file():
            h.update(str(p.relative_to(path)).encode())
            h.update(_sha256_file(p).encode())
    return h.hexdigest()


def _write_checksum_file(target: Path, checksum: str) -> None:
    """Escribe el checksum en un fichero .sha256 junto al backup."""
    chk_path = target.parent / (target.name + ".sha256")
    chk_path.write_text(f"{checksum}  {target.name}\n")
    logger.info("Checksum SHA-256 escrito en: %s", chk_path)


def _cleanup_old_backups(directory: Path, retention_days: int, pattern: str) -> int:
    """
    Elimina ficheros/directorios en `directory` que coincidan con `pattern`
    y tengan más de `retention_days` días. Devuelve cuántos se eliminaron.
    """
    now = time.time()
    cutoff = retention_days * 86400
    removed = 0

    for item in directory.glob(pattern):
        age = now - item.stat().st_mtime
        if age > cutoff:
            logger.info("Rotación: eliminando '%s' (%d días)", item.name, int(age / 86400))
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
            removed += 1

    return removed


# ─────────────────────────────────────────────────────────────────────────────
# BACKUP LÓGICO — pg_dump
# ─────────────────────────────────────────────────────────────────────────────

class LogicalBackup:
    """
    Encapsula la ejecución de pg_dump con todos sus parámetros.

    Internamente:
      1. Verifica que pg_dump está disponible en PATH.
      2. Crea el directorio de destino si no existe.
      3. Construye la lista de argumentos de pg_dump:
           - Formato custom (comprimido y paralelizable con pg_restore)
           - Nivel de compresión configurable
           - Schemas y tablas opcionales
           - Timestamp en el nombre del fichero
      4. Ejecuta pg_dump como subproceso con PGPASSWORD en el entorno.
      5. Verifica que el fichero resultante no está vacío.
      6. Calcula y guarda el checksum SHA-256.
      7. Elimina backups anteriores a retention_days.
    """

    EXTENSION = {
        "custom":    ".dump",
        "plain":     ".sql",
        "tar":       ".tar",
        "directory": "",      # directorio, sin extensión de fichero
    }

    def __init__(self, pg: PgConfig, cfg: BackupConfig):
        self.pg  = pg
        self.cfg = cfg

    def run(self) -> BackupResult:
        start = datetime.now()
        result = BackupResult(mode="logical", success=False, start_time=start)

        try:
            binary = _check_binary("pg_dump")
            logger.info("── BACKUP LÓGICO ─────────────────────────────────")
            logger.info("Host     : %s:%d", self.pg.host, self.pg.port)
            logger.info("Base     : %s", self.pg.dbname)
            logger.info("Formato  : %s", self.cfg.logical_format)
            logger.info("Compresión: %d", self.cfg.compress_level)

            # Directorio de destino
            dest_dir = self.cfg.backup_dir / "logical"
            if not self.cfg.dry_run:
                dest_dir.mkdir(parents=True, exist_ok=True)

            # Nombre del fichero destino
            timestamp = start.strftime("%Y%m%d_%H%M%S")
            ext = self.EXTENSION.get(self.cfg.logical_format, ".dump")
            dest = dest_dir / f"{self.pg.dbname}_{timestamp}{ext}"

            # Construir comando
            cmd = [
                str(binary),
                f"--host={self.pg.host}",
                f"--port={self.pg.port}",
                f"--username={self.pg.user}",
                f"--dbname={self.pg.dbname}",
                f"--format={self.cfg.logical_format}",
                "--no-password",
                "--verbose",
            ]

            # Compresión (solo para formatos que la soportan)
            if self.cfg.logical_format in ("custom", "tar"):
                cmd.append(f"--compress={self.cfg.compress_level}")

            # Schemas específicos
            for schema in self.cfg.logical_schemas:
                cmd += ["--schema", schema]

            # Tablas específicas
            for table in self.cfg.logical_tables:
                cmd += ["--table", table]

            # Formato directory: --file apunta a un directorio
            if self.cfg.logical_format == "directory":
                cmd += [f"--file={dest}"]
            else:
                cmd += [f"--file={dest}"]

            logger.info("Destino  : %s", dest)

            # ── Ejecutar pg_dump ──────────────────────────────────
            proc = _run(cmd, _build_env(self.pg), self.cfg.dry_run)

            if proc.returncode != 0:
                raise RuntimeError(
                    f"pg_dump terminó con código {proc.returncode}:\n{proc.stderr}"
                )

            result.path = dest

            # ── Verificar que el resultado no está vacío ──────────
            if self.cfg.verify and not self.cfg.dry_run:
                self._verify_dump(dest)

            # ── Checksum ──────────────────────────────────────────
            if not self.cfg.dry_run:
                if dest.is_dir():
                    checksum = _sha256_dir(dest)
                else:
                    checksum = _sha256_file(dest)
                _write_checksum_file(dest, checksum)
                result.checksum   = checksum
                result.size_bytes = _get_size(dest)

            # ── Rotación ──────────────────────────────────────────
            removed = _cleanup_old_backups(
                dest_dir,
                self.cfg.retention_days,
                f"{self.pg.dbname}_*{ext}" if ext else f"{self.pg.dbname}_*",
            )
            if removed:
                logger.info("Rotación : %d backup(s) antiguo(s) eliminados", removed)

            result.success  = True
            result.end_time = datetime.now()
            logger.info("Backup lógico completado en %.1fs", result.duration_seconds)

        except Exception as exc:
            result.end_time = datetime.now()
            result.error    = str(exc)
            logger.error("Error en backup lógico: %s", exc)

        return result

    def _verify_dump(self, dest: Path) -> None:
        """
        Verifica la integridad del dump:
        - Para formato custom/tar: ejecuta pg_restore --list (solo lee la cabecera)
        - Para formato directory: comprueba que existe backup_manifest o toc.dat
        - Para plain SQL: comprueba que el fichero no está vacío
        """
        logger.info("Verificando integridad del dump…")

        if self.cfg.logical_format == "custom":
            binary = _check_binary("pg_restore")
            proc = subprocess.run(
                [str(binary), "--list", str(dest)],
                capture_output=True, text=True,
            )
            if proc.returncode != 0:
                raise RuntimeError(f"Verificación fallida: {proc.stderr}")
            count = len(proc.stdout.strip().splitlines())
            logger.info("Verificación OK: %d objetos en el dump", count)

        elif self.cfg.logical_format == "directory":
            toc = dest / "toc.dat"
            if not toc.exists():
                raise RuntimeError(f"Verificación fallida: toc.dat no encontrado en {dest}")
            logger.info("Verificación OK: toc.dat presente")

        elif self.cfg.logical_format == "plain":
            size = dest.stat().st_size
            if size < 100:
                raise RuntimeError(f"Verificación fallida: fichero SQL sospechosamente pequeño ({size} bytes)")
            logger.info("Verificación OK: fichero SQL de %d bytes", size)

        elif self.cfg.logical_format == "tar":
            size = dest.stat().st_size
            if size == 0:
                raise RuntimeError("Verificación fallida: fichero tar vacío")
            logger.info("Verificación OK: fichero tar de %d bytes", size)


# ─────────────────────────────────────────────────────────────────────────────
# BACKUP FÍSICO — pg_basebackup
# ─────────────────────────────────────────────────────────────────────────────

class PhysicalBackup:
    """
    Encapsula la ejecución de pg_basebackup.

    Internamente:
      1. Verifica que pg_basebackup está disponible en PATH.
      2. Crea el directorio de destino con timestamp.
      3. Construye los argumentos:
           - --wal-method=stream: incluye los WAL necesarios para consistencia
           - --checkpoint=fast: no espera al siguiente checkpoint automático
           - --compress: compresión del directorio resultante
           - --progress y --verbose para observabilidad
      4. Ejecuta pg_basebackup como subproceso.
      5. Verifica que backup_label existe en el directorio resultante.
      6. Calcula y guarda el checksum SHA-256 del conjunto de ficheros.
      7. Elimina backups físicos anteriores a retention_days.
    """

    def __init__(self, pg: PgConfig, cfg: BackupConfig):
        self.pg  = pg
        self.cfg = cfg

    def run(self) -> BackupResult:
        start = datetime.now()
        result = BackupResult(mode="physical", success=False, start_time=start)

        try:
            binary = _check_binary("pg_basebackup")
            logger.info("── BACKUP FÍSICO ─────────────────────────────────")
            logger.info("Host       : %s:%d", self.pg.host, self.pg.port)
            logger.info("Usuario    : %s (debe tener rol REPLICATION)", self.pg.user)
            logger.info("WAL method : %s", self.cfg.wal_method)
            logger.info("Checkpoint : %s", self.cfg.checkpoint)

            # Directorio de destino con timestamp
            dest_dir = self.cfg.backup_dir / "physical"
            timestamp = start.strftime("%Y%m%d_%H%M%S")
            dest = dest_dir / timestamp

            if not self.cfg.dry_run:
                dest_dir.mkdir(parents=True, exist_ok=True)

            # Construir comando
            cmd = [
                str(binary),
                f"--host={self.pg.host}",
                f"--port={self.pg.port}",
                f"--username={self.pg.user}",
                f"--pgdata={dest}",
                f"--wal-method={self.cfg.wal_method}",
                f"--checkpoint={self.cfg.checkpoint}",
                f"--compress={self.cfg.compress_level}",
                "--progress",
                "--verbose",
                "--no-password",
            ]

            logger.info("Destino    : %s", dest)

            # ── Ejecutar pg_basebackup ────────────────────────────
            proc = _run(cmd, _build_env(self.pg), self.cfg.dry_run)

            if proc.returncode != 0:
                raise RuntimeError(
                    f"pg_basebackup terminó con código {proc.returncode}:\n{proc.stderr}"
                )

            result.path = dest

            # ── Verificar backup_label ────────────────────────────
            if self.cfg.verify and not self.cfg.dry_run:
                self._verify_base_backup(dest)

            # ── Checksum del directorio completo ──────────────────
            if not self.cfg.dry_run:
                checksum = _sha256_dir(dest)
                _write_checksum_file(dest, checksum)
                result.checksum   = checksum
                result.size_bytes = _get_size(dest)

            # ── Rotación ──────────────────────────────────────────
            removed = _cleanup_old_backups(dest_dir, self.cfg.retention_days, "20*")
            if removed:
                logger.info("Rotación : %d backup(s) físico(s) eliminados", removed)

            result.success  = True
            result.end_time = datetime.now()
            logger.info("Backup físico completado en %.1fs", result.duration_seconds)

        except Exception as exc:
            result.end_time = datetime.now()
            result.error    = str(exc)
            logger.error("Error en backup físico: %s", exc)

        return result

    def _verify_base_backup(self, dest: Path) -> None:
        """
        Verifica el backup físico comprobando:
        1. Existencia de backup_label (indica backup limpio completado).
        2. Existencia del directorio pg_wal o pg_wal.tar.gz.
        3. Parsea backup_label para extraer LSN y timestamp de inicio.
        """
        logger.info("Verificando integridad del backup físico…")

        label = dest / "backup_label"
        if not label.exists():
            raise RuntimeError(
                f"Verificación fallida: 'backup_label' no encontrado en {dest}. "
                "El backup puede estar incompleto."
            )

        # Parsear backup_label
        content = label.read_text()
        info = {}
        for line in content.splitlines():
            if ":" in line:
                key, _, val = line.partition(":")
                info[key.strip()] = val.strip()

        logger.info("backup_label — START WAL : %s", info.get("START WAL LOCATION", "?"))
        logger.info("backup_label — START TIME: %s", info.get("START TIME", "?"))
        logger.info("backup_label — BACKUP FROM: %s", info.get("BACKUP FROM", "?"))

        # Comprobar pg_wal (puede estar como directorio o .tar.gz si se comprimió)
        wal_dir  = dest / "pg_wal"
        wal_tar  = dest / "pg_wal.tar.gz"
        base_tar = dest / "base.tar.gz"

        if not wal_dir.exists() and not wal_tar.exists() and not base_tar.exists():
            logger.warning(
                "pg_wal no encontrado como directorio ni como tar.gz — "
                "verifique que --wal-method no es 'none'"
            )
        else:
            logger.info("Verificación OK: backup_label y pg_wal presentes")


# ─────────────────────────────────────────────────────────────────────────────
# ORQUESTADOR PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────

class BackupOrchestrator:
    """
    Coordina la ejecución de uno o ambos modos de backup,
    agrega los resultados y escribe el informe final.
    """

    def __init__(self, pg: PgConfig, cfg: BackupConfig):
        self.pg  = pg
        self.cfg = cfg

    def run(self) -> list[BackupResult]:
        logger.info("╔══════════════════════════════════════════════════╗")
        logger.info("║          PostgreSQL Backup Tool                  ║")
        logger.info("╚══════════════════════════════════════════════════╝")
        logger.info("Modo        : %s", self.cfg.mode)
        logger.info("Directorio  : %s", self.cfg.backup_dir)
        logger.info("Retención   : %d días", self.cfg.retention_days)
        logger.info("Verificación: %s", "sí" if self.cfg.verify else "no")
        if self.cfg.dry_run:
            logger.warning("⚠ DRY-RUN activado — no se realizará ningún backup real")

        results: list[BackupResult] = []

        if self.cfg.mode in ("logical", "both"):
            r = LogicalBackup(self.pg, self.cfg).run()
            results.append(r)

        if self.cfg.mode in ("physical", "both"):
            r = PhysicalBackup(self.pg, self.cfg).run()
            results.append(r)

        self._print_summary(results)
        return results

    def _print_summary(self, results: list[BackupResult]) -> None:
        logger.info("╔══════════════════════════════════════════════════╗")
        logger.info("║                   RESUMEN                       ║")
        logger.info("╚══════════════════════════════════════════════════╝")
        for r in results:
            logger.info(r.summary())
            logger.info("──────────────────────────────────────────────────")

        total_ok   = sum(1 for r in results if r.success)
        total_fail = len(results) - total_ok
        logger.info("Resultado: %d OK / %d FAIL", total_ok, total_fail)

        if total_fail > 0:
            sys.exit(1)


# ─────────────────────────────────────────────────────────────────────────────
# CLI — argumentos de línea de comandos
# ─────────────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="pg_backup.py",
        description="Herramienta de backup para PostgreSQL: lógico (pg_dump) y físico (pg_basebackup).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  # Backup lógico con valores por defecto
  python pg_backup.py --mode logical

  # Backup físico a un directorio específico
  python pg_backup.py --mode physical --backup-dir /mnt/backups

  # Backup de ambos tipos contra un servidor remoto
  python pg_backup.py --mode both --host db.ejemplo.com --port 5432 \\
      --user postgres --password secreto --db produccion

  # Solo la tabla 'ventas' del schema 'raw', formato SQL plano
  python pg_backup.py --mode logical --schemas raw --tables ventas \\
      --logical-format plain

  # Simulación sin ejecutar nada
  python pg_backup.py --mode both --dry-run

Variables de entorno aceptadas (alternativa a los argumentos):
  PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE
        """,
    )

    # Conexión
    conn = parser.add_argument_group("Conexión")
    conn.add_argument("--host",     default=os.getenv("PGHOST",     "localhost"))
    conn.add_argument("--port",     default=int(os.getenv("PGPORT", "5432")), type=int)
    conn.add_argument("--user",     default=os.getenv("PGUSER",     "postgres"))
    conn.add_argument("--password", default=os.getenv("PGPASSWORD", ""))
    conn.add_argument("--db",       default=os.getenv("PGDATABASE", "postgres"),
                      help="Base de datos (solo para backup lógico)")

    # Modo
    mode = parser.add_argument_group("Modo de backup")
    mode.add_argument(
        "--mode", choices=["logical", "physical", "both"],
        default="logical",
        help="Tipo de backup a ejecutar (default: logical)",
    )

    # Almacenamiento
    store = parser.add_argument_group("Almacenamiento")
    store.add_argument("--backup-dir",     default="/backup",
                       help="Directorio raíz de backups (default: /backup)")
    store.add_argument("--retention-days", default=7, type=int,
                       help="Días de retención antes de rotar (default: 7)")
    store.add_argument("--compress",       default=9, type=int, choices=range(0, 10),
                       metavar="0-9",
                       help="Nivel de compresión 0-9 (default: 9)")

    # Lógico
    logical = parser.add_argument_group("Opciones backup lógico (pg_dump)")
    logical.add_argument(
        "--logical-format",
        choices=["custom", "plain", "tar", "directory"],
        default="custom",
        help="Formato pg_dump (default: custom)",
    )
    logical.add_argument("--schemas", nargs="*", default=[],
                         help="Schemas a incluir (default: todos)")
    logical.add_argument("--tables",  nargs="*", default=[],
                         help="Tablas a incluir (default: todas)")

    # Físico
    physical = parser.add_argument_group("Opciones backup físico (pg_basebackup)")
    physical.add_argument(
        "--wal-method", choices=["stream", "fetch", "none"],
        default="stream",
        help="Método para incluir WAL (default: stream)",
    )
    physical.add_argument(
        "--checkpoint", choices=["fast", "spread"],
        default="fast",
        help="Tipo de checkpoint (default: fast)",
    )

    # Operación
    ops = parser.add_argument_group("Opciones de operación")
    ops.add_argument("--no-verify", action="store_true",
                     help="Omitir verificación de integridad tras el backup")
    ops.add_argument("--dry-run",   action="store_true",
                     help="Mostrar comandos sin ejecutarlos")
    ops.add_argument("--log-file",  default=None,
                     help="Ruta de fichero de log adicional")
    ops.add_argument("--verbose",   action="store_true",
                     help="Activar logging DEBUG")

    return parser.parse_args()


def setup_file_logger(log_path: Path) -> None:
    """Añade un FileHandler al logger raíz."""
    fh = logging.FileHandler(log_path, encoding="utf-8")
    fh.setFormatter(logging.Formatter(LOG_FORMAT, datefmt=DATE_FORMAT))
    logging.getLogger().addHandler(fh)
    logger.info("Log adicional en: %s", log_path)


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    if args.log_file:
        setup_file_logger(Path(args.log_file))

    pg = PgConfig(
        host=args.host,
        port=args.port,
        user=args.user,
        password=args.password,
        dbname=args.db,
    )

    cfg = BackupConfig(
        mode=args.mode,
        backup_dir=Path(args.backup_dir),
        retention_days=args.retention_days,
        compress_level=args.compress,
        logical_format=args.logical_format,
        logical_schemas=args.schemas or [],
        logical_tables=args.tables  or [],
        wal_method=args.wal_method,
        checkpoint=args.checkpoint,
        verify=not args.no_verify,
        dry_run=args.dry_run,
        log_file=Path(args.log_file) if args.log_file else None,
    )

    BackupOrchestrator(pg, cfg).run()


if __name__ == "__main__":
    main()
