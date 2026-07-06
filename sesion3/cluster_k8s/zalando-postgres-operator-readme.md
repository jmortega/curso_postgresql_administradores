# Zalando Postgres Operator — Guía Completa

> **Repositorio oficial:** https://github.com/zalando/postgres-operator
> **Versión de referencia:** v1.13.x (rama `master`)

---

## ¿Qué es el Postgres Operator de Zalando?

En Kubernetes, un **Operador** es un software que extiende la API nativa para automatizar tareas complejas que normalmente realizaría un administrador.
El Operador de Zalando lee una definición en un archivo YAML (el recurso `postgresql`) y se encarga de generar y mantener por debajo los objetos nativos de Kubernetes necesarios (`StatefulSet`, `PersistentVolumeClaim`, `Service`, `Secret`, etc.), además de:

- **Levantar automáticamente clústeres de PostgreSQL** con el número de réplicas indicado.
- **Realizar actualizaciones de versión** del motor sin tiempo de inactividad (*Rolling Updates*).
- **Gestionar dinámicamente los volúmenes** de almacenamiento persistente (`PersistentVolumeClaims`).
- **Aplicar reglas de anti-afinidad** para distribuir las réplicas en distintos nodos.
- **Crear y rotar credenciales** de usuario y bases de datos automáticamente.

Este documento sigue el siguiente orden:

1. [Instalación de las herramientas](#1-instalación-de-las-herramientas)
2. [Creación del clúster de PostgreSQL en Kubernetes](#2-creación-del-clúster-de-postgresql-en-kubernetes)
3. [Instalación y configuración del Zalando Postgres Operator](#3-instalación-y-configuración-del-zalando-postgres-operator)

> **Nota importante:** los manifiestos del apartado 2 definen *qué* clúster se quiere desplegar, pero el operador (apartado 3) es el componente que realmente lee esos manifiestos y crea los recursos en el clúster. Si aplicas el YAML del apartado 2 antes de instalar el operador, el recurso `postgresql` quedará creado pero **inactivo** (sin `StatefulSet` ni pods) hasta que el operador esté en ejecución.

---

## 1. Instalación de las herramientas

| Herramienta | Versión mínima | Notas |
|---|---|---|
| Kubernetes | 1.25+ | Minikube, Kind, EKS, GKE, AKS o cualquier distribución |
| `kubectl` | 1.25+ | Configurado y apuntando al clúster destino |
| Helm | 3.x | Para instalación vía Helm Chart |
| Docker | Cualquiera reciente | Solo si se construye la imagen localmente |

### 1.1. Instalar `kubectl`

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### 1.2. Instalar Helm en una distribución basada en Debian (Debian/Ubuntu)

Hay dos métodos habituales. Se recomienda el repositorio APT porque facilita las actualizaciones posteriores con `apt upgrade`.

#### Opción 1 — Repositorio APT oficial (paso a paso)

```bash
# 1. Instalar dependencias necesarias
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# 2. Descargar e importar la clave de firma de Helm
curl -fsSL https://baltocdn.com/helm/signing.asc \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

# 3. Añadir el repositorio APT de Helm
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] \
https://baltocdn.com/helm/stable/debian/ all main" \
  | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# 4. Actualizar índices e instalar
sudo apt-get update
sudo apt-get install -y helm
```

#### Opción 2 — Script oficial de instalación

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

#### Verificar la instalación

```bash
helm version
# version.BuildInfo{Version:"v3.x.x", ...}
```

---

## 2. Creación del clúster de PostgreSQL en Kubernetes

En este apartado se definen los manifiestos que describen el clúster de PostgreSQL: **2 instancias (1 primario + 1 réplica)**, con su volumen persistente y sus reglas de anti-afinidad de pods. Todos estos objetos son gestionados por el **Zalando Postgres Operator**, cuya instalación se detalla en el [apartado 3](#3-instalación-y-configuración-del-zalando-postgres-operator).

### 2.1. Manifiesto principal del clúster (recurso `postgresql`)

Este es el único fichero que el usuario necesita aplicar manualmente. El operador lo traduce automáticamente en un `StatefulSet`, `PersistentVolumeClaims`, `Services` y `Secrets`.

```yaml
# cluster-postgres.yaml
apiVersion: "acid.zalan.do/v1"
kind: postgresql
metadata:
  name: mi-cluster-postgres
  namespace: default
spec:
  teamId: "mi-equipo"
  numberOfInstances: 2        # 1 primario + 1 réplica
  postgresql:
    version: "16"
    parameters:
      max_connections: "100"
      shared_buffers: "256MB"
  volume:
    size: 10Gi
    storageClass: standard    # StorageClass del clúster K8s
  users:
    mi_usuario:
      - superuser
      - createdb
  databases:
    mi_base_de_datos: mi_usuario
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 1Gi
  # --- Reglas de anti-afinidad de pods ---
  # Evita que el primario y la réplica se programen en el mismo nodo físico.
  podAnnotations:
    scheduler.alpha.kubernetes.io/critical-pod: "true"
  tolerations: []
  nodeAffinity: {}
```

### 2.2. Habilitar la anti-afinidad de pods a nivel de operador

La anti-afinidad **no se define dentro del propio recurso `postgresql`**, sino en la configuración global del operador (`ConfigMap` o `values.yaml` de Helm).
El operador la aplica automáticamente al `StatefulSet` que genera para cada clúster:

```yaml
# valores relevantes en la configuración del operador
enable_pod_antiaffinity: "true"
pod_antiaffinity_topology_key: "kubernetes.io/hostname"
```

Esto hace que el `StatefulSet` generado incluya, en su plantilla de pod, una regla equivalente a:

```yaml
# fragmento generado automáticamente dentro del StatefulSet
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: cluster-name
              operator: In
              values:
                - mi-cluster-postgres
        topologyKey: "kubernetes.io/hostname"
```

Con esta regla, Kubernetes **no programará dos pods del mismo clúster en el mismo nodo**, garantizando alta disponibilidad real ante el fallo de un nodo.

### 2.3. Referencia: `StatefulSet` generado por el operador

El operador crea un `StatefulSet` equivalente a este, con 2 réplicas según `numberOfInstances`:

```yaml
# Referencia informativa — generada automáticamente por el operador
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mi-cluster-postgres
  namespace: default
  labels:
    application: spilo
    cluster-name: mi-cluster-postgres
spec:
  serviceName: mi-cluster-postgres
  replicas: 2
  selector:
    matchLabels:
      cluster-name: mi-cluster-postgres
  template:
    metadata:
      labels:
        application: spilo
        cluster-name: mi-cluster-postgres
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: cluster-name
                    operator: In
                    values:
                      - mi-cluster-postgres
              topologyKey: "kubernetes.io/hostname"
      containers:
        - name: postgres
          image: ghcr.io/zalando/spilo-16:3.2-p1
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: pgdata
              mountPath: /home/postgres/pgdata
  volumeClaimTemplates:
    - metadata:
        name: pgdata
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: standard
        resources:
          requests:
            storage: 10Gi
```

### 2.4. Referencia: `PersistentVolumeClaim` generado por instancia

Por cada pod del `StatefulSet` (uno por instancia) se genera un PVC individual siguiendo el `volumeClaimTemplate` anterior:

```yaml
# Referencia informativa — generada automáticamente por el operador
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pgdata-mi-cluster-postgres-0
  namespace: default
  labels:
    cluster-name: mi-cluster-postgres
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pgdata-mi-cluster-postgres-1
  namespace: default
  labels:
    cluster-name: mi-cluster-postgres
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 10Gi
```

> Para que el redimensionado posterior del volumen (`kubectl patch ... spec.volume.size`) funcione, la `StorageClass` debe tener `allowVolumeExpansion: true`.

### 2.5. Aplicar el manifiesto del clúster

Una vez el operador esté instalado y en ejecución (apartado 3):

```bash
kubectl apply -f cluster-postgres.yaml
```

---

## 3. Instalación y configuración del Zalando Postgres Operator

### 3.1. Instalación vía Helm (recomendada)

```bash
# 1. Añadir el repositorio de charts de Zalando
helm repo add zalando-postgres-operator \
  https://opensource.zalando.com/postgres-operator/charts/postgres-operator

"zalando-postgres-operator" has been added to your repositories

# 2. Actualizar el índice local
helm repo update

# 3. Instalar el operador en su propio namespace
helm install postgres-operator \
  zalando-postgres-operator/postgres-operator \
  --namespace postgres-operator \
  --create-namespace

NAME: postgres-operator
LAST DEPLOYED: Sun Jul  5 20:03:47 2026
NAMESPACE: postgres-operator
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
To verify that postgres-operator has started, run:

  kubectl --namespace=postgres-operator get pods -l "app.kubernetes.io/name=postgres-operator"

```

Verificar que el pod del operador está en ejecución:

```bash
kubectl get pods -n postgres-operator
# NOMBRE                             READY   STATUS    RESTARTS
# postgres-operator-<hash>           1/1     Running   0
```

### 3.2. Instalación alternativa vía manifiestos YAML (sin Helm)

```bash
git clone https://github.com/zalando/postgres-operator.git
cd postgres-operator

kubectl apply -f manifests/operator-service-account-rbac.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: postgres-operator
  namespace: default

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: postgres-operator
rules:
# all verbs allowed for custom operator resources
- apiGroups:
  - acid.zalan.do
  resources:
  - postgresqls
  - postgresqls/status
  - operatorconfigurations
  verbs:
  - create
  - delete
  - deletecollection
  - get
  - list
  - patch
  - update
  - watch
# operator only reads PostgresTeams
- apiGroups:
  - acid.zalan.do
  resources:
  - postgresteams
  verbs:
  - get
  - list
  - watch
# all verbs allowed for event streams (Zalando-internal feature)
# - apiGroups:
#   - zalando.org
#   resources:
#   - fabriceventstreams
#   verbs:
#   - create
#   - delete
#   - deletecollection
#   - get
#   - list
#   - patch
#   - update
#   - watch
# to create or get/update CRDs when starting up
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - customresourcedefinitions
  verbs:
  - create
  - get
  - patch
  - update
# to read configuration from ConfigMaps and help Patroni manage the cluster if endpoints are not used
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - create
  - delete
  - deletecollection
  - get
  - list
  - patch
  - update
  - watch
# to send events to the CRs
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - get
  - list
  - patch
  - update
  - watch
# to manage endpoints which are also used by Patroni (if it is using config maps)
- apiGroups:
  - ""
  resources:
  - endpoints
  verbs:
  - create
  - delete
  - deletecollection
  - get
  - list
  - patch
  - update
  - watch
# to CRUD secrets for database access
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - create
  - delete
  - get
  - update
  - patch
# to check nodes for node readiness label
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
# to read or delete existing PVCs. Creation via StatefulSet
- apiGroups:
  - ""
  resources:
  - persistentvolumeclaims
  verbs:
  - delete
  - get
  - list
  - patch
  - update
 # to read existing PVs. Creation should be done via dynamic provisioning
- apiGroups:
  - ""
  resources:
  - persistentvolumes
  verbs:
  - get
  - list
  - update  # only for resizing AWS volumes
# to watch Spilo pods and do rolling updates. Creation via StatefulSet
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - delete
  - get
  - list
  - patch
  - update
  - watch
# to resize the filesystem in Spilo pods when increasing volume size
- apiGroups:
  - ""
  resources:
  - pods/exec
  verbs:
  - create
# to CRUD services to point to Postgres cluster instances
- apiGroups:
  - ""
  resources:
  - services
  verbs:
  - create
  - delete
  - get
  - patch
  - update
# to CRUD the StatefulSet which controls the Postgres cluster instances
- apiGroups:
  - apps
  resources:
  - statefulsets
  - deployments
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
# to CRUD cron jobs for logical backups
- apiGroups:
  - batch
  resources:
  - cronjobs
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
# to get namespaces operator resources can run in
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
# to define PDBs. Update happens via delete/create
- apiGroups:
  - policy
  resources:
  - poddisruptionbudgets
  verbs:
  - create
  - delete
  - get
# to create ServiceAccounts in each namespace the operator watches
- apiGroups:
  - ""
  resources:
  - serviceaccounts
  verbs:
  - get
  - create
# to create role bindings to the postgres-pod service account
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - rolebindings
  verbs:
  - get
  - create
# to grant privilege to run privileged pods (not needed by default)
#- apiGroups:
#  - extensions
#  resources:
#  - podsecuritypolicies
#  resourceNames:
#  - privileged
#  verbs:
#  - use

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: postgres-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: postgres-operator
subjects:
- kind: ServiceAccount
  name: postgres-operator
  namespace: default

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: postgres-pod
rules:
# Patroni needs to watch and manage config maps (or endpoints)
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - create
  - delete
  - deletecollection
  - get
  - list
  - patch
  - update
  - watch
# Patroni needs to watch and manage endpoints (or config maps)
- apiGroups:
  - ""
  resources:
  - endpoints
  verbs:
  - create
  - delete
  - deletecollection
  - get
  - list
  - patch
  - update
  - watch
# Patroni needs to watch pods
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - patch
  - update
  - watch
# to let Patroni create a headless service
- apiGroups:
  - ""
  resources:
  - services
  verbs:
  - create
# to grant privilege to run privileged pods (not needed by default)
#- apiGroups:
#  - extensions
#  resources:
#  - podsecuritypolicies
#  resourceNames:
#  - privileged
#  verbs:
#  - use

kubectl apply -f manifests/postgres-operator.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-operator
  labels:
    application: postgres-operator
spec:
  replicas: 1
  strategy:
    type: "Recreate"
  selector:
    matchLabels:
      name: postgres-operator
  template:
    metadata:
      labels:
        name: postgres-operator
    spec:
      serviceAccountName: postgres-operator
      containers:
      - name: postgres-operator
        image: ghcr.io/zalando/postgres-operator:v1.15.1
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            cpu: 100m
            memory: 250Mi
          limits:
            cpu: 500m
            memory: 500Mi
        securityContext:
          runAsUser: 1000
          runAsNonRoot: true
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
        env:
        # provided additional ENV vars can overwrite individual config map entries
        - name: CONFIG_MAP_NAME
          value: "postgres-operator"
        # In order to use the CRD OperatorConfiguration instead, uncomment these lines and comment out the two lines above
        # - name: POSTGRES_OPERATOR_CONFIGURATION_OBJECT
        #  value: postgresql-operator-default-configuration
        # Define an ID to isolate controllers from each other
        # - name: CONTROLLER_ID
        #   value: "second-operator"

kubectl apply -f manifests/api-service.yaml

apiVersion: v1
kind: Service
metadata:
  name: postgres-operator
spec:
  type: ClusterIP
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    name: postgres-operator

```

### 3.3. (Opcional) Interfaz web del operador

$ helm search repo zalando-postgres-operator
$ helm search repo postgres-operator-ui-charts

# Repo del operador
$ helm repo add zalando-postgres-operator https://opensource.zalando.com/postgres-operator/charts/postgres-operator

# Repo separado para la UI
$ helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui

$ helm repo update

```bash
helm install postgres-operator-ui \
  postgres-operator-ui-charts/postgres-operator-ui \
  --namespace postgres-operator


kubectl port-forward svc/postgres-operator-ui 8081:80 -n postgres-operator
# Abrir http://localhost:8081 en el navegador
```

### 3.4. Configuración del operador

# Parámetros de configuración — New cluster configuration (Postgres Operator UI)

## Identificación del cluster

| Parámetro | Descripción |
|---|---|
| **Name** | Nombre único del cluster PostgreSQL (`mi-cluster-postgres`). Se traduce a `metadata.name` en el YAML del CRD `postgresql.acid.zalan.do`. |
| **Owning team** | Equipo propietario (`teamId`). El operador usa este valor para nombrar recursos derivados y, si la Teams API está habilitada, para resolver roles/superusuarios asociados a ese equipo. |
| **PostgreSQL version** | Versión mayor de PostgreSQL a desplegar (`17`). Determina la imagen Spilo utilizada internamente. |
| **DNS name** | Campo informativo (no editable) que muestra el nombre DNS interno resultante: `<name>.<namespace>`. |

---

## Topología del cluster

| Parámetro | Descripción |
|---|---|
| **Number of instances** | Número total de pods PostgreSQL: 1 actúa como *master* (lectura/escritura) y el resto como réplicas en streaming replication gestionada por Patroni. |
| **Enable load balancer** (Master / Replica) | Crea un `Service` tipo `LoadBalancer` (p. ej. un ELB en AWS) para exponer externamente el master y/o las réplicas de solo lectura. |
| **Enable connection pooler** (Master / Replica) | Despliega un **pgBouncer** delante del master y/o de las réplicas para hacer pooling de conexiones y reducir la sobrecarga de conexiones directas a Postgres. |
| **Enable connection pooler load balancer** (Master / Replica) | Igual que el load balancer normal, pero expone el tráfico a través del pooler en lugar de conectar directamente a Postgres. |

---

## Almacenamiento

| Parámetro | Descripción |
|---|---|
| **Volume size** | Tamaño del `PersistentVolumeClaim` (PVC) creado para los datos de cada instancia (`10 Gi`). |
| **storageClass** | `StorageClass` de Kubernetes que define el tipo de disco subyacente (SSD/HDD, proveedor de EBS, etc.) — en este caso `standard`. |
| **Iops** | IOPS provisionadas para el volumen. Solo aplica a storage classes compatibles (ej. `gp3` en AWS EBS). Si se deja vacío, se usa el valor por defecto (**3000 IOPS**). |
| **Throughput** | Ancho de banda (MB/s) provisionado para el volumen, también exclusivo de storage classes tipo `gp3`. Por defecto **125 MB/s** si no se especifica. |

---

## Gestión de usuarios y bases de datos

| Parámetro | Descripción |
|---|---|
| **Users** (botón +) | Permite definir roles/usuarios de PostgreSQL que el operador creará automáticamente al provisionar el cluster (con sus privilegios: `superuser`, `createdb`, `login`, etc.). |
| **Databases** (botón +) | Permite declarar bases de datos a crear junto con su usuario propietario (`owner`), evitando tener que crearlas manualmente vía `psql` tras el despliegue. |

---

## Seguridad de red

| Parámetro | Descripción |
|---|---|
| **Add host** (campo IP `/32`) | Corresponde a `spec.allowedSourceRanges`: rangos CIDR permitidos para acceder al cluster a través del load balancer. Aquí se añade IP por IP con máscara `/32` (host único). Si se deja vacío, no se restringe el acceso por origen (o se aplica el valor por defecto del operador). |

---

## Recursos (CPU / Memoria)

| Parámetro | Descripción |
|---|---|
| **CPU – Request** | `100m` (0.1 vCPU): recurso **garantizado** que Kubernetes reserva para el pod al programarlo. Es el valor que compara el scheduler contra la capacidad disponible del nodo. |
| **CPU – Limit** | `500m` (0.5 vCPU): tope máximo de CPU que el pod puede llegar a consumir antes de ser *throttled*. |
| **Memory – Request** | `100 Mi`: memoria garantizada reservada para el pod. **Este es el valor que provoca errores `Insufficient memory` si el nodo no tiene esa cantidad libre.** |
| **Memory – Limit** | `500 Mi`: tope máximo de memoria; si el pod lo supera, Kubernetes lo mata por OOM (`OOMKilled`). |

> 💡 **Nota práctica:** el *request* es lo que determina si el pod se puede programar o no (error `FailedScheduling`), mientras que el *limit* solo afecta al comportamiento en tiempo de ejecución una vez el pod ya está corriendo. Ante problemas de scheduling por memoria, baja primero el **Memory Request** (no el Limit) o reduce el **Number of instances**.


### 3.5. Verificación y monitorización del clúster

```bash
# Ver el recurso postgresql
$ kubectl get postgresql -n default
NAME                  TEAM   VERSION   PODS   VOLUME   CPU-REQUEST   MEMORY-REQUEST   AGE     STATUS
mi-cluster-postgres   acid   17        3      20Gi     250m          512Mi            5m40s   Running


# Ver los pods del clúster
$ kubectl get pods -l application=spilo -n default
NAME                    READY   STATUS    RESTARTS   AGE
mi-cluster-postgres-0   1/1     Running   0          5m59s
mi-cluster-postgres-1   1/1     Running   0          3m11s
mi-cluster-postgres-2   1/1     Running   0          3m10s

$ kubectl get pods -l application=spilo -n default -L spilo-role
NAME                    READY   STATUS    RESTARTS   AGE    SPILO-ROLE
mi-cluster-postgres-0   1/1     Running   0          10m    master
mi-cluster-postgres-1   1/1     Running   0          8m7s   replica
mi-cluster-postgres-2   1/1     Running   0          8m6s   replica


# Ver los servicios expuestos
$ kubectl get svc -l application=spilo -n default
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
mi-cluster-postgres          LoadBalancer   10.99.215.232   <pending>     5432:31627/TCP   6m13s
mi-cluster-postgres-config   ClusterIP      None            <none>        <none>           3m21s
mi-cluster-postgres-repl     LoadBalancer   10.104.99.55    <pending>     5432:30422/TCP   6m13s

```

Ver eventos y logs:

```bash
kubectl describe postgresql mi-cluster-postgres -n default
kubectl logs -n postgres-operator deployment/postgres-operator -f
```

### 3.6. Acceder a la base de datos

El operador crea automáticamente un Secret con las credenciales:

```bash
# Obtener el nombre del secret (formato: <usuario>.<cluster>.credentials)
kubectl get secrets -n default | grep mi-cluster-postgres

# Extraer usuario y contraseña
kubectl get secret postgres.mi-cluster-postgres.credentials \
  -n default \
  -o jsonpath='{.data.password}' | base64 -d
```

Conectarse mediante port-forward:

```bash
kubectl get pods -l application=spilo,spilo-role=master -n default
NAME                    READY   STATUS    RESTARTS   AGE
mi-cluster-postgres-0   1/1     Running   0          15m

kubectl port-forward pod/mi-cluster-postgres-0 5432:5432 -n default

psql -h localhost -p 5432 -U postgres -d postgres
```

### 3.7. Operaciones habituales

**Escalar el número de réplicas:**

```bash
kubectl patch postgresql mi-cluster-postgres \
  --type='merge' \
  -p '{"spec":{"numberOfInstances":3}}' \
  -n default
```

**Actualizar la versión de PostgreSQL:**

```bash
kubectl patch postgresql mi-cluster-postgres \
  --type='merge' \
  -p '{"spec":{"postgresql":{"version":"17"}}}' \
  -n default
```

**Ampliar el volumen de almacenamiento:**

```bash
kubectl patch postgresql mi-cluster-postgres \
  --type='merge' \
  -p '{"spec":{"volume":{"size":"50Gi"}}}' \
  -n default
```

**Eliminar un clúster:**

```bash
kubectl delete postgresql mi-cluster-postgres -n default
```

> **Atención:** esto elimina también los `PersistentVolumeClaims` si el operador está configurado para ello. Realizar una copia de seguridad antes de borrar.

---

## Estructura de recursos creados por el operador

```
postgresql (CRD)
├── StatefulSet          → gestiona los pods de PostgreSQL (con anti-afinidad)
├── Services
│   ├── <cluster>        → apunta siempre al primario (lectura/escritura)
│   └── <cluster>-repl   → apunta a las réplicas (solo lectura)
├── PersistentVolumeClaims → almacenamiento de cada instancia (uno por pod)
├── Secrets
│   └── <usuario>.<cluster>.credentials → usuario + contraseña generados
└── Endpoints            → actualizados dinámicamente por Patroni
```

---

## Solución de problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| Pod en estado `Pending` | Sin nodos disponibles, `StorageClass` inexistente o anti-afinidad imposible de cumplir | Revisar `kubectl describe pod` y disponibilidad de nodos |
| Clúster en estado `SyncFailed` | Error de configuración en el YAML | Ver logs del operador con `kubectl logs` |
| No se crean los Secrets | Permisos RBAC insuficientes | Verificar `ServiceAccount` y `ClusterRoleBinding` |
| Réplica no sincroniza | Problema de red entre pods | Revisar políticas de red (`NetworkPolicy`) |
| `PVC` no se redimensiona | `StorageClass` sin soporte de expansión | Usar `StorageClass` con `allowVolumeExpansion: true` |
| Ambos pods en el mismo nodo | `enable_pod_antiaffinity` no activado en el operador | Configurar `enable_pod_antiaffinity: "true"` (ver apartado 3.4) |

---

## Referencias

- Repositorio oficial: https://github.com/zalando/postgres-operator
- Documentación completa: https://opensource.zalando.com/postgres-operator/
- Helm Chart: https://github.com/zalando/postgres-operator/tree/master/charts
- Instalación de Helm: https://helm.sh/docs/intro/install/
- Spilo (imagen base): https://github.com/zalando/spilo
- Patroni (HA para PostgreSQL): https://github.com/patroni/patroni
