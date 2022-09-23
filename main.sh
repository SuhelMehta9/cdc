#

# Run the other sh files

# Open a new terminal and check the status of the Kafka Connect service:
curl -H "Accept:application/json" localhost:8083/

# Check the list of connectors registered with Kafka Connect:
curl -H "Accept:application/json" localhost:8083/connectors/

# Adding connector
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" localhost:8083/connectors/ -d '{ "name": "inventory-connector", "config": { "connector.class": "io.debezium.connector.mysql.MySqlConnector", "tasks.max": "1", "database.hostname": "mysql", "database.port": "3306", "database.user": "debezium", "database.password": "dbz", "database.server.id": "184054", "database.server.name": "dbserver1", "database.include.list": "inventory", "database.history.kafka.bootstrap.servers": "kafka:9092", "database.history.kafka.topic": "dbhistory.inventory" } }'

#  Verifying connector
curl -H "Accept:application/json" localhost:8083/connectors/

# Review connector's task
curl -i -X GET -H "Accept:application/json" localhost:8083/connectors/inventory-connector

# Viewing event change (This can be order 5)
docker run -it --rm --name watcher --link zookeeper:zookeeper --link kafka:kafka quay.io/debezium/kafka:1.9 watch-topic -a -k dbserver1.inventory.customers