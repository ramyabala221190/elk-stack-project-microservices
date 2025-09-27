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