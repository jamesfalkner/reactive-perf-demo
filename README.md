# Quarkus performance test demo

A sample reactive and non-reactive [Quarkus](https://quarkus.io) app using the mssql extension, along with a [Gatling](https://gatling.io/open-source/) workload to run against it.

The idea is to run the Quarkus app on one host, connected to a SQL Server database, then run the Gatling workloads across one or more separate hosts.

## Prereqs

1. A host running SQL Server 2017 or later
2. A host capable of running Quarkus apps (e.g. with Java 11 installed)
3. A host capable of running Gatling (e.g. with Java 11 installed)

## Manual steps
1. Deploy SQL Server, create a `fruits` database, remember your username/passsword
2. Set values in `application.properties` for your DB connection, and build and deploy the Quarkus app JAR on a separate (or same) host - either the one in `reactive-app` or `non-reactive-app`
3. Run the Quarkus app (e.g. `java -jar /tmp/app.jar`), make sure it connects to DB properly
4. Add some data through `curl`, e.g. `curl -X POST -H 'Content-Type:application/json' -d '{"name": "Apple"}' http://localhost:8080/fruits`
5. Install Gatling on the host you want to run the workload on
6. Copy the `fruits` simulation code directory from the `simulations` directory in this repo to the Gatling simulations directory within the Gatling deployment from the previous step (e.g. into `user-files/simulations/fruits`)
7. set `QHOST` and `QPORT` environment variables to point to the Quarkus host/port and run the Gatling workload on the gatling host e.g. `/home/user/gatling/bin/gatling.sh -s fruits.Basic500user` (you can see the names of the different simulations in [BasicSimulation.scala](simulaions/../simulations/fruits/BasicSimulation.scala) )
8. Enjoy the results!

# Automated run across multiple hosts

Check out the [scripts/azure-sim.sh](scripts/azure-sim.sh) for an example shell script you can use to automatically run the test across multiple hosts.

## Prereqs

1. A host running SQL Server 2017 or later that is accessible from the host running the Quarkus app.
2. A host capable of running Quarkus apps
3. One or more hosts capable of running Gatling workload
4. The Quarkus and workload machines must be ssh'able
5. It is assumed they are running Ubuntu as the script uses `apt-get` to install Java and Zip/Unzip utilities.

To use it, you need to install Gatling locally first, and then set the following environment variables and run the script:

```sh
#
# You must set GATLING_HOME to where you installed gatling on your local machine
#
GATLING_LOCAL_HOME=/my/gatling/installation

# The host/port that should run the quarkus app
export QHOST=${QHOST:-"1.1.1.1"}
export QPORT=${QPORT:-"8080"}

# The host that is running sqlserver (must be accessible from QHOST, so you can also
# use the private IP address if both Quarkus and SQL Server hosts are on the same subnet
export SHOST="1.1.1.1"

# A space-separated list of hosts to run the gatling workload across (must be able to ssh to these)
export GHOSTS="1.1.1.1 2.2.2.2 3.3.3.3"

# The username of the user able to ssh into all the hosts
export SSH_USER=azureuser

# The path to the private key used for SSH_USER
export SSH_KEY=$HOME/.ssh/azure

# Simulation class name
export SIMULATION_NAME="fruits.Async500d2000u"

# Where to locally store intermediate results from each workload host
export INTERMEDIATE_RESULTS_DIR="/tmp/gather-results"

# Set DB URL and username/password
# For a reactive app, something like 'vertx-reactive:sqlserver://$SHOST'
# For a non-reactive app, something like 'jdbc:sqlserver://$SHOST'
export QUARKUS_APP_DATASOURCE_URL="vertx-reactive:sqlserver://$SHOST"
export QUARKUS_APP_DATASOURCE_USERNAME=sa
export QUARKUS_APP_DATASOURCE_PASSWORD=mysupersecretpassword
```

The script will prepare all the hosts, run the Gatling workload, and gather all the results into an aggregated report at the end!

# Metrics

Each sample app has metrics enabled. If you want to easily visualize them, edit the `prometheus.yml` file in the root of this repo and change the IP address under `targets` to your Quarkus application IP address. Then you can run prometheus using Docker:

```bash
docker run -it  \
    -p 9090:9090 \
    -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus
```

And access it at `localhost:9090` in your browser to issue queries. 