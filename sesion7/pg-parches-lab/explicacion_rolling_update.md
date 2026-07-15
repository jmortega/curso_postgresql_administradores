# Explicación de la ejecución — Práctica 2: Rolling Update con Patroni

La ejecución fue un **éxito completo**: el clúster pasó de `pgprimary` como líder a `pgreplica1` como líder, con las tres réplicas terminando sanas y sincronizadas, en un total de ~74 segundos (17:11:20 → 17:12:34).

---

## Fase 0 — Estado inicial y prerrequisitos ✅

```
pgprimary  | Leader  | running
pgreplica1 | Replica | streaming | Lag 0 MB
pgreplica2 | Replica | streaming | Lag 0 MB
```

Lag de replicación en 0s, sin transacciones largas bloqueando — el script continúa sin activar ningún `warn`/`fail`.

---

## Fase 1 — Actualización de réplicas (una a una) ✅

Para cada réplica (`pgreplica1`, luego `pgreplica2`) el patrón se repite limpiamente:

1. `patronictl pause` → Patroni deja de gestionar el clúster automáticamente
2. `docker restart` del contenedor de esa réplica
3. `patronictl resume` → Patroni retoma el control
4. `wait_node_healthy` detecta el estado `streaming` casi de inmediato
5. Lag tras el reinicio: **0s** en ambos casos — la réplica se resincronizó sin acumular retraso

Los reinicios se reportan como completados en **0s**, lo cual es plausible en un laboratorio local sin carga real: el contenedor arranca y PostgreSQL/Patroni reconectan casi instantáneamente. En un entorno de producción real, aquí verías segundos u minutos reales de reinicio.

---

## Fase 2 — Switchover controlado (el momento crítico) ✅

```bash
patronictl switchover --master pgprimary --candidate pgreplica1 --force
```

Aquí ocurre lo más delicado de todo el proceso, y se ve reflejado en el estado transicional:

```
pgprimary  | Replica | stopped   ← momento exacto del corte
pgreplica1 | Leader  | running   ← ya promovido
pgreplica2 | Replica | running
```

El antiguo primario aparece brevemente como `stopped` mientras se degrada a réplica — es la ventana real de "no aceptar escrituras" del rolling update. El script espera 15s y luego confirma que `pgreplica1` es el nuevo líder.

**RTO reportado: 19s.**

> ⚠️ **Ojo con este número:** como el script hace `sleep 15` fijo dentro de la medición del switchover, ese "RTO" **incluye la espera artificial del propio script**, no solo el tiempo real que Patroni tardó en promover. El corte de servicio real probablemente fue mucho menor a 19s — para medir el RTO real necesitarías cronometrar desde que la última escritura falla hasta que la primera escritura nueva tiene éxito, no desde que se lanza el comando hasta que termina un `sleep` fijo.

---

## Fase 3 — Actualizar el antiguo primario (`pgprimary`) ✅

Se pausa, reinicia y reanuda igual que las réplicas, y vuelve al clúster como `streaming` en segundos.

> **Detalle menor:** esta fase no imprime el tiempo de reinicio (`Reinicio completado en Xs`) como sí hacía el bucle de réplicas — es una asimetría de logging del script (usa `docker restart` directo sin medir `RESTART_START`/`RESTART_END`), no un fallo funcional.

---

## Estado final: correcto y saludable

```
pgprimary  | Replica | streaming | TL 3
pgreplica1 | Leader  | running   | TL 3
pgreplica2 | Replica | streaming | TL 3
```

- El **timeline** subió de `2` a `3` en los tres nodos — es la marca esperada de que ocurrió una promoción real (cada failover/switchover incrementa el timeline de WAL).
- `pg_stat_replication` final muestra `pgreplica2` en `sync_state = sync` y `pgprimary` en `async` — Patroni reasignó automáticamente cuál réplica actúa como síncrona tras el cambio de topología, comportamiento normal y esperado.

---

## Resumen

El rolling update se ejecutó de principio a fin **sin errores**, con **lag cero en todo momento** y el clúster terminando en un estado consistente y saludable.
