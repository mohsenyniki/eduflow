# Week 2 — key takeaways and concepts

## Docker fundamentals

### Image vs container
- **Image** — a frozen, read-only recipe (blueprint). Lives on disk, does nothing on its own.
- **Container** — a running instance of an image (the meal). Live, dynamic, can write data.
- One image can create many containers. Same recipe, multiple meals.
- In our stack: `apache/airflow:2.9.1` is one image that creates three containers (webserver, scheduler, worker).

### Containerization
- Containers are NOT virtual machines. VMs have their own full operating system. Containers share the host OS kernel but are isolated from each other.
- VM analogy: three separate houses on a plot of land, each with its own foundation.
- Container analogy: three apartments in one building, each private but sharing the same foundation.
- "Containerizing" = packaging a service with everything it needs so it runs identically anywhere.

### Docker daemon
- A background process that runs quietly, waiting to receive instructions.
- `docker compose up` sends instructions TO the daemon, the daemon does the actual work.
- Docker Desktop must be open because it starts the daemon. Without it, commands go nowhere.

### Ports
- A numbered door on a computer. One IP address, many ports.
- Each service claims one port and only responds to traffic on that number.
- Key ports in our stack:
  - `2181` — Zookeeper
  - `9092` — Kafka (external, your Mac)
  - `29092` — Kafka (internal, between containers)
  - `5432` — PostgreSQL
  - `4566` — LocalStack
  - `6379` — Redis
  - `8080` — Airflow webserver

### Volumes
- Persistent storage that lives outside containers on your Mac.
- Without a volume: data disappears when a container stops.
- With a volume: data survives restarts.
- Two-part syntax: inside service = "mount this volume here", at root level = "create and manage this volume".

### docker-compose.yml structure
- `services:` — defines all containers
- `volumes:` — defines persistent storage (root level, zero indentation)
- `depends_on:` — startup dependency order
- `condition: service_healthy` — wait for health check to pass
- `condition: service_completed_successfully` — wait for container to finish and exit cleanly (used for init containers)
- `environment:` — configuration passed into the container at startup

---

## CLI commands learned

### Docker commands
```bash
docker compose up              # start all services
docker compose up <service>    # start one specific service
docker compose down            # stop and remove all containers
docker compose ps              # show status of running containers
docker compose ps -a           # show all containers including stopped ones
docker compose logs -f         # stream logs from all services
docker system df               # show disk usage by images, containers, volumes
docker system prune -a         # remove unused images, stopped containers, build cache
docker volume prune            # remove volumes not attached to any container
docker info | grep -i memory   # check Docker's total memory allocation
docker stats --no-stream       # show live memory/CPU usage per container
docker exec <container> <cmd>  # run a command inside a running container
docker exec -it <container> bash  # open an interactive shell inside a container
```

### The -it flags
- `-i` — keep output flowing to your terminal so you can see it
- `-t` — format the output like a normal terminal session
- Use together (`-it`) whenever you need to interact with a container or see formatted output

### bash -c
- Opens a bash shell inside the container before running the command
- Required when your command uses shell features: `$()`, pipes `|`, `&&`, `||`
- Without it, shell syntax gets passed as literal text instead of being evaluated

### grep
- Searches through text for a specific word or phrase
- `-q` flag means quiet — doesn't print anything, just exits with pass or fail
- `-i` flag means case-insensitive
- Used consistently in health checks: `curl <url> | grep -q '<expected text>' || exit 1`

### curl
- Makes HTTP requests from the terminal (like a browser but for the command line)
- `-f` flag means fail — returns a failure exit code on HTTP error responses instead of printing them
- Used to hit health endpoints: `curl -f http://localhost:<port>/<health-path>`

### || exit 1
- "If everything on the left failed, run what's on the right"
- Used at the end of health check commands to ensure Docker gets a clear failure signal

---

## Service-specific CLI tools

Each service has its own built-in CLI tool. Use the right tool for the right service:

| Service | Tool | Health check command |
|---|---|---|
| Zookeeper | `nc` (netcat) | `echo srvr \| nc localhost 2181` |
| Kafka | `kafka-broker-api-versions` | `kafka-broker-api-versions --bootstrap-server localhost:9092` |
| PostgreSQL | `pg_isready` | `pg_isready -U airflow` |
| LocalStack | `curl` | `curl -f http://localhost:4566/_localstack/health` |
| Redis | `redis-cli` | `redis-cli ping` → expects `PONG` |
| Airflow scheduler | `airflow jobs check` | `airflow jobs check --job-type SchedulerJob --hostname $(hostname)` |
| Airflow worker | `celery inspect` | `celery --app airflow.executors.celery_executor.app inspect ping` |

---

## HTTP vs HTTPS
- **HTTP** — plain text communication between browser and server. Fine for local development.
- **HTTPS** — encrypted communication using TLS. Required for anything on the public internet.
- We use `http://localhost:8080` locally because traffic never leaves the machine, nothing to intercept.
- In production, Airflow would be behind HTTPS so login credentials are encrypted.

---

## Airflow architecture

### The four components
- **Webserver** — browser UI at `http://localhost:8080`. Shows DAGs, logs, run history.
- **Scheduler** — watches the clock, triggers tasks in the right order, sends them to Redis.
- **Worker** — picks tasks up from Redis and actually executes them.
- **Metadata database (PostgreSQL)** — Airflow's long-term memory. Stores run history, task states, logs.

### What Airflow does vs doesn't do
- **Does:** watches the clock, triggers tasks in order, checks success/failure, retries, alerts
- **Does NOT:** touch data, clean anything, move files, process events
- Airflow is the project manager. Spark is the engineer who does the actual work.

### Init container pattern
- `airflow-init` runs once, creates database tables and admin user, then exits.
- Other services use `condition: service_completed_successfully` to wait for it.
- This pattern (run once and exit) is called an init container.

### CeleryExecutor
- The execution mode where tasks are sent to separate worker processes via Redis.
- Scheduler → Redis → Worker is the task flow.
- Alternative is LocalExecutor (runs tasks in the scheduler process, lighter but less scalable).

---

## Redis
- An in-memory data store. Extremely fast because everything lives in RAM.
- In our setup: the message broker between Airflow scheduler and worker.
- Scheduler drops a task in Redis, worker picks it up and executes it.
- No volume needed because it's a temporary queue. If it restarts, scheduler re-queues tasks.
- Default port: 6379.

---

## LocalStack
- Simulates AWS services locally for free.
- We only enable S3 (`SERVICES=s3`) to save memory.
- Port 4566 is LocalStack's single port for all AWS services.
- Code talking to LocalStack is identical to code talking to real AWS, just the endpoint URL differs.
- S3 status shows as `available` not `running` in the health endpoint.

---

## Storage formats: Parquet vs JSON

### Row-based storage (JSON, CSV)
- Stores data row by row: all columns for row 1, then all columns for row 2, etc.
- Reading one column requires reading all columns for every row.
- Inefficient for analytics questions that only need specific columns.

### Columnar storage (Parquet)
- Stores data column by column: all values for column 1, then all values for column 2, etc.
- Reading one column skips all other columns entirely.
- Dramatically faster for analytics workloads.
- Compresses better because repeated values (like country names) sit next to each other.
- Typically 5-10x smaller than equivalent JSON.

### Why we use Parquet in S3
- Events come out of Kafka as JSON (fine for transport).
- Once in S3 for storage and Spark processing, we convert to Parquet.
- Spark will ask column-focused questions (students per country, average processing time, etc.).
- Parquet is optimized exactly for this type of query.

### Key term: predicate pushdown
- A Parquet feature where Spark can skip entire file chunks that don't match a filter, without reading them at all.

---

## Dependency order in our stack

```
Start immediately (no dependencies):
├── Zookeeper
├── PostgreSQL
├── Redis
└── LocalStack

Wait for Zookeeper:
└── Kafka
    └── Generator (waits for Kafka)

Wait for PostgreSQL:
└── airflow-init
    ├── Airflow Webserver (waits for postgres + redis + airflow-init)
    ├── Airflow Scheduler (waits for postgres + redis + airflow-init)
    └── Airflow Worker (waits for postgres + redis + airflow-init)
```

Most critical services (most others depend on them):
- **PostgreSQL** — if it goes down, all three Airflow services fail
- **Zookeeper** — if it goes down, Kafka goes down, generator fails, Airflow can't consume events
- **Redis** — if it goes down, scheduler can't send tasks to worker, nothing executes
