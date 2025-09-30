# Logging in Microservices

Challenges of logging in microservices:
1. distributed in nature: Need to locate in which microservice the issue is occuring.
2. log correlation
3. high volume
4. centralisation and management

What is observability ?

Ability to understand the internal state of the system by examining the outputs.
This is possible using logs,metrics, alerts and traces.

Popular logging libraries:

1. winston
2. pino
3. morgan
4. bunyan
5. log4js

Logging Levels:

1. Fatal: Fatal errors can bring the entire app down
2. Error: error in app  that is fatal only for the current operation but the rest of the app continues to function
3. Warning:potential issues but app works
4. info: important details like startup,shutdown
5. debug: state of the app for debugging
6. trace: most detailed logging level. It is used to find the specific place where the error has occured.


Log formats:
1. Unstructured: not recommended. eg: common and combined log format
2. Structured: most recommended. eg: json,xml,key-value pair
3. semi-strucutured

Best Practices

1. Use log levels effectively
2. use structured json
3. use iso-8601 timestamps
4. standardise context like include eventId, microservice name, file detaild, method name, line no etc
5. use correlation id and stack traces
6. be selective for privacy and compliance. do not log sensitive information.

We are using winston + morgan in the microservices project and the gateway project to append the log messages to files. These files are then picked by Filebeat and sent to the ELK stack.

# ELK
The ELK Stack works by using Beats or Logstash to collect data from various sources, Logstash to process and transform it, Elasticsearch to index and store the data, and Kibana to visualize and analyze it through dashboards and charts. Essentially, data is gathered, sent to Elasticsearch for analysis, and then displayed in Kibana for monitoring and troubleshooting purposes.

So each of the microservices and the gateways have the filebeat to collect the log messages. Filebeat will send the log messages to logstash,
which in turn will send it to elastic search. Kibana provides a visual display.

Elastic provides official Docker images for Elasticsearch, Logstash, and Kibana. These images contain the necessary software and dependencies for each component.

# Running in docker

```
docker compose -p elk -f elk/docker-compose.yml build

docker compose -p elk -f elk/docker-compose.yml  up -d --remove-orphans --no-build

```

- Kibana: [http://localhost:5601](http://localhost:5601)
- Elasticsearch: [http://localhost:9200](http://localhost:9200)
- LogStash is listening on 5000 and 5001.


# Logstash

Logstash is the gateway to centralised logging system

Ways of injesting logs:

1. direct transport: directly sending the logs to elastic search

2. file: write the logs to a file. logstash/filebeat then picks up the file, parses them and sends them to elastic search

We are using the 2nd method, where filebeat picks the logs from the file, sends to logstash, which in turn sends to elastic search.

Logstash pipeline is configured using a yml file. It has 3 main sections: input, filter and output

The Logstash configuration is defined in the [`logstash.conf`](./logstash/logstash.conf) file. This configuration listens for Filebeat input on port `5001` and TCP input on port `5000`, and sends the logs to Elasticsearch.

Observe the index field. It picks up the service_name field from the logs. Recall that this has been added to log message for each microservice.
This helps to differentiate between the logs of different microservices and gateways.

```
output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    # index => "app-%{+YYYY.MM.dd}"
    index => "%{[service_name]}-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}


```

Hit localhost:5601 to access the Kibana dashboard.
On the RHS, go to Stack Management ---> Index Management.
You can see an index for every microservice