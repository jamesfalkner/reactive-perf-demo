#!/bin/bash
# see https://medium.com/@vcomposieux/load-testing-gatling-tips-tricks-47e829e5d449
# Also add inbound NSG for VirtualNetwork port 1433
# Also open RHEL firewall
#   sudo firewall-cmd --zone=public --add-port=1433/tcp --permanent
#   sudo firewall-cmd --reload
# and open port 8080 on quarkus VM
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

#
# You must set GATLING_HOME to where you installed gatling
#
GATLING_LOCAL_HOME=${GATLING_LOCAL_HOME:-"${SCRIPT_DIR}/../../gatling"}

# Where to download Gatling bundle from to run workload on GHOSTS
GATLING_DOWNLOAD_URL=${GATLING_DOWNLOAD_URL:-"https://repo1.maven.org/maven2/io/gatling/highcharts/gatling-charts-highcharts-bundle/3.6.1/gatling-charts-highcharts-bundle-3.6.1-bundle.zip"}

# The host/port that should run the quarkus app
export QHOST=${QHOST:-"1.1.1.1"}
export QPORT=${QPORT:-"8080"}

# The host that is running sqlserver (must be accessible from QHOST, so you can also
# use the private IP address if both Quarkus and SQL Server hosts are on the same subnet
export SHOST=${SHOST:-"1.1.1.1"}

# A space-separated list of hosts to run the gatling workload across (must be able to ssh to these)
export GHOSTS=( ${GHOSTS:-"1.1.1.1 2.2.2.2 3.3.3.3"} ) 

# The username of the user able to ssh into all the hosts
export SSH_USER=${SSH_USER:-"azureuser"}

# The path to the private key used for SSH_USER
export SSH_KEY=${SSH_KEY:-"$HOME/.ssh/azure"}

# If you want to skip the rebuild/copy of the quarkus app, set this to a non-empty value
# This is useful if you are doing multiple runs on the same hosts and saves time if you don't need to rebuild the app
export SKIP_BUILD=${SKIP_BUILD:-''}

# Where to put gatling on GHOSTS hosts
GATLING_REMOTE_HOME=/home/${SSH_USER}/gatling

# Where to find results on the GHOSTS hosts
GATLING_REMOTE_SIMULATIONS_DIR=${GATLING_REMOTE_HOME}/user-files/simulations

# Simulation class name
SIMULATION_NAME=${SIMULATION_NAME:-"fruits.Async500d2000u"}
GATLING_REMOTE_REPORT_DIR=${GATLING_REMOTE_HOME}/results
INTERMEDIATE_RESULTS_DIR=${INTERMEDIATE_RESULTS_DIR:-"/tmp/gather-results"}
QUARKUS_APP_DIR=${QUARKUS_APP_DIR:-${SCRIPT_DIR}/../reactive-app}

# Set DB URL and username/password
# For a reactive app, something like 'vertx-reactive:sqlserver://$SHOST'
# For a non-reactive app, something like 'jdbc:sqlserver://$SHOST'
QUARKUS_APP_DATASOURCE_URL=${QUARKUS_APP_DATASOURCE_URL:-"vertx-reactive:sqlserver://$SHOST"}
QUARKUS_APP_DATASOURCE_USERNAME=${QUARKUS_APP_DATASOURCE_USERNAME:-"sa"}
QUARKUS_APP_DATASOURCE_PASSWORD=${QUARKUS_APP_DATASOURCE_PASSWORD:-"supersecretpassword"}

# prepare qhost
ssh -i ${SSH_KEY} ${SSH_USER}@$QHOST sudo apt-get install -y zip unzip openjdk-11-jre-headless
echo "skip build: $SKIP_BUILD"

if [[ -z "${SKIP_BUILD}" ]] ; then
  mvn -f ${QUARKUS_APP_DIR} clean package -DskipTests -Dquarkus.package.type=uber-jar || exit 1
  scp -i ${SSH_KEY} ${QUARKUS_APP_DIR}/target/*-runner.jar ${SSH_USER}@$QHOST:/tmp/app.jar 
fi

# re-run the quarkus app on QHOST
ssh -i ${SSH_KEY} ${SSH_USER}@$QHOST pkill java
ssh -i ${SSH_KEY} ${SSH_USER}@$QHOST "sh -c 'nohup java -Dquarkus.datasource.reactive.url=${QUARKUS_APP_DATASOURCE_URL} -Dquarkus.datasource.username=\"${QUARKUS_APP_DATASOURCE_USERNAME}\" -Dquarkus.datasource.password=\"${QUARKUS_APP_DATASOURCE_PASSWORD}\" -jar /tmp/app.jar > /tmp/quarkus.log 2>&1 &'"

echo "Waiting for quarkus app to start up..."
until curl http://$QHOST:$QPORT > /dev/null 2>&1
do
    echo  .
    sleep 1
done

echo
curl -X POST -H 'Content-Type:application/json' -d '{"name": "foo1"}' http://$QHOST:$QPORT/fruits
curl -X POST -H 'Content-Type:application/json' -d '{"name": "foo2"}' http://$QHOST:$QPORT/fruits
curl -X POST -H 'Content-Type:application/json' -d '{"name": "foo3"}' http://$QHOST:$QPORT/fruits
curl -X POST -H 'Content-Type:application/json' -d '{"name": "foo4"}' http://$QHOST:$QPORT/fruits

if ! curl http://$QHOST:$QPORT/fruits > /dev/null 2>&1 ; then
  echo "cant curl, app isnt running"
  exit 1
fi

# Prepare ghosts
for GHOST in "${GHOSTS[@]}"
do
    ssh -i ${SSH_KEY} ${SSH_USER}@$GHOST pkill java
    ssh -i ${SSH_KEY} ${SSH_USER}@$GHOST sudo apt-get install -y zip unzip openjdk-11-jre-headless
    ssh -i ${SSH_KEY} ${SSH_USER}@$GHOST wget -q -O /tmp/gatling.zip $GATLING_DOWNLOAD_URL
    ssh -i ${SSH_KEY} ${SSH_USER}@$GHOST rm -rf /home/${SSH_USER}/gatling\*
    ssh -i ${SSH_KEY} ${SSH_USER}@$GHOST unzip -q -d /home/${SSH_USER} /tmp/gatling.zip
    ssh -i ${SSH_KEY} ${SSH_USER}@$GHOST mv /home/${SSH_USER}/gatling\* /home/${SSH_USER}/gatling
    scp -i ${SSH_KEY} -r ${SCRIPT_DIR}/../simulations/* ${SSH_USER}@$GHOST:/home/${SSH_USER}/gatling/user-files/simulations
done

## run the tests

echo "Cleaning previous intermediate results from localhost"
rm -rf $INTERMEDIATE_RESULTS_DIR
mkdir -p $INTERMEDIATE_RESULTS_DIR

for GHOST in "${GHOSTS[@]}"
do
  echo "Cleaning previous runs from host: $GHOST"
  ssh -i ${SSH_KEY} -n -f ${SSH_USER}@$GHOST pkill java

  ssh -i ${SSH_KEY} -n -f ${SSH_USER}@$GHOST "sh -c 'rm -rf $GATLING_REMOTE_REPORT_DIR'"
done

for GHOST in "${GHOSTS[@]}"
do
  echo "Running simulation on host: $GHOST"
  ssh -i ${SSH_KEY} -n -f ${SSH_USER}@$GHOST "sh -c 'QHOST=$QHOST QPORT=$QPORT nohup $GATLING_REMOTE_HOME/bin/gatling.sh -nr -s $SIMULATION_NAME > /tmp/run.log 2>&1 &'"
done

echo "Press return when you think run is done or want to stop it manually"
read foo

# gather reports
for GHOST in "${GHOSTS[@]}"
do
  echo "Stopping remote workloads and gathering result file from host: $GHOST"
  ssh -i ${SSH_KEY} ${SSH_USER}@$GHOST pkill java
  ssh -i ${SSH_KEY} -n -f ${SSH_USER}@$GHOST "sh -c 'ls -t $GATLING_REMOTE_REPORT_DIR | head -n 1 | xargs -I {} mv ${GATLING_REMOTE_REPORT_DIR}/{} ${GATLING_REMOTE_REPORT_DIR}/report'"
  scp -i ${SSH_KEY} ${SSH_USER}@$GHOST:${GATLING_REMOTE_REPORT_DIR}/report/simulation.log ${INTERMEDIATE_RESULTS_DIR}/simulation-$GHOST.log
done

DATESTAMP=$(date '+%m-%d-%Y-%H-%M-%S')
RESULTS_NAME=results-$(basename $QUARKUS_APP_DIR)-$DATESTAMP
mv $INTERMEDIATE_RESULTS_DIR ${SCRIPT_DIR}/../results/${RESULTS_NAME}
echo "Aggregating simulations"
${GATLING_LOCAL_HOME}/bin/gatling.sh -ro ${SCRIPT_DIR}/../results/${RESULTS_NAME}
