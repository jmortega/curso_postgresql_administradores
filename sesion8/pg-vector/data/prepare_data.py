"""
data/prepare_data.py
====================
Genera los datos de prueba estructurados que usa el laboratorio:
  · documentos.json  — 50 documentos de texto con categoría
  · productos.json   — 30 productos con descripción y precio
  · usuarios.json    — 20 usuarios con lista de intereses

Los embeddings se generan en pgvector_lab.py usando sentence-transformers
o numpy aleatorio como fallback.  Este fichero sólo crea la parte textual.

Uso
---
  python data/prepare_data.py
"""

import json
import random
from pathlib import Path

random.seed(42)
OUT = Path(__file__).parent

# ── Documentos ────────────────────────────────────────────────
CATEGORIAS_DOC = ["tecnología", "ciencia", "historia", "arte", "economía"]

DOCUMENTOS_BASE = [
    # tecnología
    ("Introducción a los transformers", "Los transformers son arquitecturas de red neuronal basadas en mecanismos de atención que revolucionaron el procesamiento del lenguaje natural.", "tecnología"),
    ("Redes neuronales convolucionales", "Las CNN extraen características espaciales de imágenes mediante filtros aprendidos en capas sucesivas.", "tecnología"),
    ("Bases de datos vectoriales", "Las bases de datos vectoriales permiten almacenar y buscar embeddings de alta dimensionalidad de forma eficiente.", "tecnología"),
    ("Docker y contenedores", "Docker empaqueta aplicaciones junto a sus dependencias en contenedores reproducibles y portables.", "tecnología"),
    ("Kubernetes en producción", "Kubernetes orquesta contenedores a escala, gestionando despliegues, escalado y tolerancia a fallos.", "tecnología"),
    ("PostgreSQL avanzado", "PostgreSQL ofrece extensiones como pgvector, PostGIS y pg_stat_statements para casos de uso especializados.", "tecnología"),
    ("APIs REST con FastAPI", "FastAPI permite construir APIs REST asíncronas en Python con validación automática mediante Pydantic.", "tecnología"),
    ("Microservicios y event sourcing", "Los microservicios distribuyen la lógica en servicios independientes que se comunican mediante eventos.", "tecnología"),
    ("MLOps: despliegue de modelos", "MLOps aplica prácticas DevOps al ciclo de vida de modelos de machine learning en producción.", "tecnología"),
    ("Graph Neural Networks", "Las GNN extienden las redes neuronales a datos de grafos, capturando relaciones estructurales entre nodos.", "tecnología"),
    # ciencia
    ("Mecánica cuántica básica", "La mecánica cuántica describe el comportamiento de partículas subatómicas mediante funciones de onda y probabilidades.", "ciencia"),
    ("Relatividad general de Einstein", "La relatividad general reformula la gravedad como curvatura del espacio-tiempo causada por la masa.", "ciencia"),
    ("CRISPR y edición genética", "CRISPR-Cas9 permite editar secuencias de ADN con precisión, abriendo nuevas posibilidades en medicina.", "ciencia"),
    ("Cambio climático y modelos", "Los modelos climáticos integran física, química y biología para predecir el impacto del calentamiento global.", "ciencia"),
    ("Neurociencia cognitiva", "La neurociencia cognitiva estudia las bases neurales de la percepción, memoria y toma de decisiones.", "ciencia"),
    ("Biología sintética", "La biología sintética diseña organismos con funciones nuevas combinando ingeniería y biología molecular.", "ciencia"),
    ("Astrofísica de agujeros negros", "Los agujeros negros son regiones donde la gravedad supera la velocidad de escape de la luz.", "ciencia"),
    ("Computación cuántica", "Los computadores cuánticos usan qubits en superposición para resolver problemas intratables clásicamente.", "ciencia"),
    # historia
    ("La Revolución Industrial", "La Revolución Industrial transformó la economía europea del siglo XVIII con la mecanización de la producción.", "historia"),
    ("El Imperio Romano", "Roma dominó el Mediterráneo durante siglos, dejando un legado jurídico, lingüístico y arquitectónico duradero.", "historia"),
    ("Segunda Guerra Mundial", "El conflicto 1939-1945 involucró a la mayoría de naciones y redefinió el orden geopolítico mundial.", "historia"),
    ("La Ruta de la Seda", "La Ruta de la Seda conectó Asia, Oriente Medio y Europa facilitando el comercio y el intercambio cultural.", "historia"),
    ("Civilizaciones mesoamericanas", "Mayas, aztecas e incas desarrollaron sistemas matemáticos, astronómicos y arquitectónicos avanzados.", "historia"),
    # arte
    ("El Renacimiento italiano", "El Renacimiento recuperó el ideal clásico grecorromano con figuras como Da Vinci, Miguel Ángel y Rafael.", "arte"),
    ("Arte abstracto del siglo XX", "Kandinsky y Mondrian liberaron la pintura de la representación figurativa buscando formas puras.", "arte"),
    ("Fotografía como arte", "La fotografía evolucionó de documento técnico a medio artístico capaz de capturar emoción y concepto.", "arte"),
    ("Arquitectura contemporánea", "Zaha Hadid y Frank Gehry llevaron las formas orgánicas y el parametrismo a la arquitectura global.", "arte"),
    # economía
    ("Teoría de juegos", "La teoría de juegos modela situaciones estratégicas donde los resultados dependen de las decisiones de múltiples agentes.", "economía"),
    ("Criptomonedas y blockchain", "Bitcoin introdujo el consenso descentralizado mediante prueba de trabajo y cadenas de bloques inmutables.", "economía"),
    ("Macroeconomía keynesiana", "Keynes argumentó que la demanda agregada impulsa el empleo y que el gasto público puede estabilizar ciclos.", "economía"),
    ("Globalización y comercio", "La globalización integró mercados globales reduciendo barreras comerciales y transformando cadenas de suministro.", "economía"),
    ("Finanzas conductuales", "Las finanzas conductuales estudian cómo los sesgos cognitivos afectan las decisiones financieras reales.", "economía"),
]

# Añadir más variantes hasta llegar a 50
EXTRAS = [
    ("Procesamiento del lenguaje natural", "El PLN usa modelos estadísticos y redes neuronales para comprender y generar texto humano.", "tecnología"),
    ("Sistemas de recomendación", "Los sistemas de recomendación predicen preferencias del usuario mediante filtrado colaborativo o basado en contenido.", "tecnología"),
    ("Seguridad en redes", "La ciberseguridad protege infraestructuras digitales ante ataques mediante cifrado, firewalls y monitorización.", "tecnología"),
    ("Evolución de los vertebrados", "Los vertebrados evolucionaron desde peces primitivos hasta mamíferos en cientos de millones de años.", "ciencia"),
    ("Física de partículas", "El modelo estándar describe las partículas fundamentales y las fuerzas que gobiernan el universo.", "ciencia"),
    ("La Guerra Fría", "La rivalidad EE.UU.-URSS entre 1947 y 1991 marcó la geopolítica global con carreras armamentísticas y espaciales.", "historia"),
    ("Música barroca", "Bach, Handel y Vivaldi crearon el barroco musical, caracterizado por el contrapunto y el ornamento.", "arte"),
    ("El mercado de valores", "Los mercados de valores permiten a empresas captar capital y a inversores participar en su crecimiento.", "economía"),
    ("Aprendizaje por refuerzo", "El aprendizaje por refuerzo entrena agentes que maximizan recompensas acumuladas mediante interacción con un entorno.", "tecnología"),
    ("Termodinámica clásica", "La termodinámica estudia las relaciones entre calor, trabajo y energía en sistemas macroscópicos.", "ciencia"),
    ("Colonialismo europeo", "El colonialismo europeo del siglo XIX remodelóó economías, fronteras y culturas en África, Asia y América.", "historia"),
    ("Diseño gráfico digital", "Herramientas como Figma y Adobe democratizaron el diseño gráfico profesional para equipos distribuidos.", "arte"),
    ("Inflación y política monetaria", "Los bancos centrales ajustan tasas de interés para controlar la inflación y estimular el crecimiento.", "economía"),
    ("Visión por computador", "La visión por computador permite a máquinas interpretar imágenes y vídeo mediante redes convolucionales profundas.", "tecnología"),
    ("Genómica y secuenciación", "La secuenciación masiva del ADN permite análisis genómicos que antes requerían décadas de trabajo.", "ciencia"),
    ("Imperios asiáticos medievales", "El Imperio Mongol, el Sultanato de Delhi y la Dinastía Tang marcaron siglos de hegemonía en Asia.", "historia"),
    ("Escultura contemporánea", "Artistas como Jeff Koons y Anish Kapoor redefinen la escultura usando materiales industriales y escala monumental.", "arte"),
    ("Mercados emergentes", "Los mercados emergentes de Asia, Latam y África representan el motor del crecimiento económico global.", "economía"),
]

DOCUMENTOS = DOCUMENTOS_BASE + EXTRAS
assert len(DOCUMENTOS) == 50, f"Se esperaban 50 docs, hay {len(DOCUMENTOS)}"

docs_json = [
    {"id": i + 1, "titulo": t, "contenido": c, "categoria": cat}
    for i, (t, c, cat) in enumerate(DOCUMENTOS)
]

# ── Productos ────────────────────────────────────────────────
PRODUCTOS = [
    ("MacBook Pro 16\"",         "Portátil profesional con chip M3 Max, 36 GB RAM y pantalla Liquid Retina XDR.", 3499.00, "electrónica"),
    ("Sony WH-1000XM5",          "Auriculares inalámbricos con cancelación de ruido líder del mercado y 30 h de batería.", 349.00,  "audio"),
    ("Kindle Paperwhite",        "Lector de e-books con pantalla sin reflejos, resistencia al agua y batería de semanas.", 149.99,  "electrónica"),
    ("Silla ErgoChair Pro",      "Silla ergonómica con soporte lumbar ajustable, reposabrazos 4D y malla transpirable.", 599.00,  "mobiliario"),
    ("Monitor LG 4K 27\"",       "Monitor IPS 4K con cobertura DCI-P3 95 %, ideal para diseño gráfico y programación.", 499.00,  "monitores"),
    ("Teclado mecánico Keychron","Teclado mecánico inalámbrico compatible con Mac/Windows, switches Gateron Brown.", 119.00,  "periféricos"),
    ("iPad Pro 12.9\"",          "Tablet profesional con chip M2, pantalla Liquid Retina y Apple Pencil compatible.", 1299.00, "electrónica"),
    ("Cámara Sony A7 IV",        "Cámara mirrorless full-frame de 33 MP con vídeo 4K 120fps y estabilización IBIS.", 2799.00, "fotografía"),
    ("DJI Mini 4 Pro",           "Dron de 249 g con cámara 4K HDR, evitación de obstáculos omnidireccional y 34 min de vuelo.", 959.00,  "drones"),
    ("Samsung Galaxy S24 Ultra", "Smartphone Android premium con S Pen integrado, cámara 200 MP y Snapdragon 8 Gen 3.", 1299.00, "móviles"),
    ("Apple Watch Ultra 2",      "Smartwatch de aventura con GPS dual, altímetro barométrico y carcasa de titanio.", 899.00,  "wearables"),
    ("Nvidia RTX 4090",          "GPU de gama alta para juegos y IA con 24 GB GDDR6X y arquitectura Ada Lovelace.", 1999.00, "componentes"),
    ("NAS Synology DS923+",      "Servidor NAS de 4 bahías con CPU AMD Ryzen, ideal para copia de seguridad y media.", 599.00,  "almacenamiento"),
    ("Logitech MX Master 3S",    "Ratón inalámbrico de productividad con scroll electromagnético y 8 botones programables.", 99.00,   "periféricos"),
    ("Impresora 3D Bambu Lab X1","Impresora FDM multicolor con calibración automática y velocidad de 500 mm/s.", 1199.00, "impresión3D"),
    ("Raspberry Pi 5",           "Computador de placa única con procesador Cortex-A76 de 4 núcleos a 2.4 GHz y 8 GB RAM.", 89.00,   "SBC"),
    ("Altavoz Sonos Era 300",    "Altavoz Dolby Atmos inalámbrico con sonido espacial y compatibilidad AirPlay 2.", 449.00,  "audio"),
    ("Projector Xgimi Horizon",  "Proyector Full HD Android TV con 2200 lúmenes y corrección automática de keystone.", 799.00,  "proyectores"),
    ("Router ASUS ZenWiFi Pro",  "Sistema WiFi 6E de malla con cobertura de 680 m² y seguridad AiProtection Pro.", 549.00,  "redes"),
    ("UPS APC 1500VA",           "Sistema de alimentación ininterrumpida con 8 salidas y protección contra sobretensiones.", 249.00,  "energía"),
    ("Mechanical Keyboard HHKB", "Teclado compacto profesional con switches Topre electrostáticos y distribución 60%.", 299.00,  "periféricos"),
    ("Webcam Elgato Facecam",    "Cámara web Full HD 1080p60 con sensor Sony y sin compresión para streaming.", 179.00,  "streaming"),
    ("SSD Samsung 990 Pro 2TB",  "SSD NVMe PCIe 4.0 con velocidades de lectura de 7450 MB/s para máximo rendimiento.", 199.00,  "almacenamiento"),
    ("AirPods Pro 2ª gen",       "Auriculares inalámbricos con chip H2, cancelación activa adaptativa y estuche MagSafe.", 279.00,  "audio"),
    ("Kindle Scribe",            "Lector y bloc de notas digital con pantalla de 10.2\" y lápiz incluido.", 369.99,  "electrónica"),
    ("Mesa de pie Flexispot E7", "Escritorio eléctrico con patas de doble motor, memoria de 4 posiciones y tope anti-colisión.", 549.00,  "mobiliario"),
    ("Tarjeta capturadora Elgato","Capturadora 4K60 Pro con compatibilidad HDR y latencia ultrabaja para streaming.", 199.00,  "streaming"),
    ("Google Pixel Watch 2",     "Smartwatch con Fitbit integrado, ECG, SpO2 y sensor de temperatura corporal.", 349.00,  "wearables"),
    ("Teclado Nuphy Air96",      "Teclado mecánico hot-swap de perfil bajo con switches Gateron Low Profile.", 129.00,  "periféricos"),
    ("Micrófono Blue Yeti X",    "Micrófono de condensador USB con cuatro patrones polares y monitorización en tiempo real.", 169.00,  "audio"),
]

productos_json = [
    {"id": i + 1, "nombre": n, "descripcion": d, "precio": p, "categoria": c}
    for i, (n, d, p, c) in enumerate(PRODUCTOS)
]

# ── Usuarios ────────────────────────────────────────────────
USUARIOS = [
    ("Elena García",    ["inteligencia artificial", "Python", "base de datos", "cloud computing"]),
    ("Carlos Martínez", ["fotografía", "viajes", "arquitectura", "diseño gráfico"]),
    ("Laura Sánchez",   ["música clásica", "piano", "literatura", "cine independiente"]),
    ("Andrés López",    ["videojuegos", "esports", "streaming", "hardware PC"]),
    ("Marta Rodríguez", ["cocina", "gastronomía", "vinos", "recetas vegetarianas"]),
    ("David Fernández", ["senderismo", "escalada", "trail running", "naturaleza"]),
    ("Isabel Torres",   ["moda", "diseño de interiores", "arte contemporáneo", "sostenibilidad"]),
    ("Pablo Jiménez",   ["finanzas", "inversión", "criptomonedas", "macroeconomía"]),
    ("Sofía Moreno",    ["biología marina", "oceanografía", "buceo", "conservación"]),
    ("Raúl Pérez",      ["astronomía", "astrofísica", "telescopios", "ciencia espacial"]),
    ("Carmen Ruiz",     ["yoga", "meditación", "psicología positiva", "mindfulness"]),
    ("Javier Díaz",     ["robótica", "Arduino", "impresión 3D", "electrónica maker"]),
    ("Patricia Gómez",  ["cómics", "animación", "ilustración digital", "manga"]),
    ("Miguel Serrano",  ["historia medieval", "arqueología", "numismática", "cultura clásica"]),
    ("Ana Blanco",      ["data science", "visualización de datos", "estadística", "R"]),
    ("Sergio Molina",   ["ciclismo", "MTB", "nutrición deportiva", "triatlón"]),
    ("Rosa Ortega",     ["jardinería", "botánica", "permacultura", "vida rural"]),
    ("Tomás Castro",    ["emprendimiento", "startups", "product management", "lean startup"]),
    ("Lucía Iglesias",  ["teatro", "danza contemporánea", "literatura dramática", "improvisación"]),
    ("Héctor Vargas",   ["seguridad informática", "pentesting", "CTF", "redes"]),
]

usuarios_json = [
    {"id": i + 1, "nombre": n, "intereses": intereses}
    for i, (n, intereses) in enumerate(USUARIOS)
]

# ── Guardar JSON ─────────────────────────────────────────────
(OUT / "documentos.json").write_text(
    json.dumps(docs_json, ensure_ascii=False, indent=2), encoding="utf-8"
)
(OUT / "productos.json").write_text(
    json.dumps(productos_json, ensure_ascii=False, indent=2), encoding="utf-8"
)
(OUT / "usuarios.json").write_text(
    json.dumps(usuarios_json, ensure_ascii=False, indent=2), encoding="utf-8"
)

print(f"✓ documentos.json — {len(docs_json)} documentos")
print(f"✓ productos.json  — {len(productos_json)} productos")
print(f"✓ usuarios.json   — {len(usuarios_json)} usuarios")
