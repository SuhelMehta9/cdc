#!/bin/bash

# Run order: 1
# docker command used: docker run -it --rm --name zookeeper -p 2181:2181 -p 2888:2888 -p 3888:3888 quay.io/debezium/zookeeper:1.9

# Exit immediately if a *pipeline* returns a non-zero status. (Add -x for command tracing)
set -e

echo "Run this command from project root dir"
echo "Please enter zookeeper path (without / at end): "
read zookeeper_path
curl https://dlcdn.apache.org/zookeeper/zookeeper-3.6.3/apache-zookeeper-3.6.3-bin.tar.gz -o $zookeeper_path/apache_zookeeper.tar.gz
tar -xzf apache_zookeeper.tar.gz
mv $zookeeper_path/apache-zookeeper-3.6.3-bin $zookeeper_path/apache_zookeeper
export ZK_HOME="$zookeeper_path/apache_zookeeper" # take this as input from user
if [[ -z "$LOG_LEVEL" ]]; then
    LOG_LEVEL="INFO"
fi
sed -i -r -e "s|\\$\\{zookeeper.root.logger\\}|$LOG_LEVEL, CONSOLE|g" $ZK_HOME/conf/log4j.properties
sed -i -r -e "s|\\$\\{zookeeper.console.threshold\\}|$LOG_LEVEL|g" $ZK_HOME/conf/log4j.properties
# make data dir
mkdir "$ZK_HOME/data"
# make log dir
mkdir "$ZK_HOME/txns"
# check if zoo.cfg exist, if yes then copy otherwise don't copy
cp samples/sample_zoo.cfg $ZK_HOME/conf/zoo.cfg
sed -i -r -e "s|_DATA_DIR_|$ZK_HOME/data|g" $ZK_HOME/conf/zoo.cfg
sed -i -r -e "s|_TXNS_|$ZK_HOME/txns|g" $ZK_HOME/conf/zoo.cfg
# set above values in zoo.cfg
export ZOOCFGDIR="$ZK_HOME/conf"
export ZOOCFG="zoo.cfg"
exec $ZK_HOME/bin/zkServer.sh start-foreground

if [[ -z $1 ]]; then
    ARG1="start"
else
    ARG1=$1
fi

if [[ -n "$JMXPORT" ]]; then
    # Docker requires extra JMX-related JVM flags beyond what Zookeeper normally uses
    JMX_EXTRA_FLAGS="-Djava.rmi.server.hostname=${JMXHOST} -Dcom.sun.management.jmxremote.rmi.port=${JMXPORT} -Dcom.sun.management.jmxremote.port=${JMXPORT}"
    if [[ -n "$JVMFLAGS" ]]; then
        export JVMFLAGS="${JMX_EXTRA_FLAGS} ${JVMFLAGS} "
    else
        export JVMFLAGS="${JMX_EXTRA_FLAGS} "
    fi
fi

# Process some known arguments to run Zookeeper ...
case $ARG1 in
    start)
        # Copy config files if not provided in volume
        export ZK_HOME="/home/chintu/Documents/cdc/apache-zookeeper-3.6.3-bin"
        cp -rn $ZK_HOME/conf.orig/* $ZK_HOME/conf

        #
        # Process the logging-related environment variables. Zookeeper's log configuration allows *some* variables to be
        # set via environment variables, and more via system properties (e.g., "-Dzookeeper.console.threshold=INFO").
        # However, in the interest of keeping things straightforward and in the spirit of the immutable image, 
        # we don't use these and instead directly modify the Log4J configuration file (replacing the variables).
        #
        if [[ -z "$LOG_LEVEL" ]]; then
            LOG_LEVEL="INFO"
        fi
        sed -i -r -e "s|\\$\\{zookeeper.root.logger\\}|$LOG_LEVEL, CONSOLE|g" $ZK_HOME/conf/log4j.properties
        sed -i -r -e "s|\\$\\{zookeeper.console.threshold\\}|$LOG_LEVEL|g" $ZK_HOME/conf/log4j.properties

        #
        # Configure cluster settings
        #
        if [[ -z "$SERVER_ID" ]]; then
            SERVER_ID="1"
        fi
        if [[ -z "$SERVER_COUNT" ]]; then
            SERVER_COUNT=1
        fi
        if [[ $SERVER_ID = "1" ]] && [[ $SERVER_COUNT = "1" ]]; then
            echo "Starting up in standalone mode"
        else
            echo "Starting up ${SERVER_ID} of ${SERVER_COUNT}"
            #
            # Append the server addresses to the configuration file ...
            #
            echo "" >> $ZK_HOME/conf/zoo.cfg
            echo "#Server List" >> $ZK_HOME/conf/zoo.cfg
            for i in $( eval echo {1..$SERVER_COUNT});do
                if [ "$SERVER_ID" = "$i" ];then
                    echo "server.$i=0.0.0.0:2888:3888" >> $ZK_HOME/conf/zoo.cfg
                else
                    echo "server.$i=zookeeper-$i:2888:3888" >> $ZK_HOME/conf/zoo.cfg
                fi
            done
            #
            # Persists the ID of the current instance of Zookeeper in the 'myid' file
            #
            echo ${SERVER_ID} > $ZK_HOME/data/myid
        fi

        # Now start the Zookeeper server
        export ZOOCFGDIR="$ZK_HOME/conf"
        export ZOOCFG="zoo.cfg"
        exec $ZK_HOME/bin/zkServer.sh start-foreground
        ;;
    status)
        exec $ZK_HOME/bin/zkServer.sh status
        ;;
    cli)
        exec "$ZK_HOME/bin/zkCli.sh -server 0.0.0.0:2181"
        ;;
esac

# Otherwise just run the specified command
exec "$@"