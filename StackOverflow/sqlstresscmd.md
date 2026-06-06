# sqlstresscmd
- https://github.com/ErikEJ/SqlQueryStress/blob/master/src/SqlQueryStressCLI/README.md

# sample.json
```
{
  "CollectIoStats": true,
  "CollectTimeStats": true,
  "CommandTimeout": 30,
  "ConnectionTimeout": 15,
  "DelayBetweenQueries": 0,
  "EnableConnectionPooling": true,
  "ForceDataRetrieval": false,
  "KillQueriesOnCancel": true,
  "MainDbConnectionInfo": {
    "ApplicationIntent": 0,
    "ConnectTimeout": 15,
    "Database": "StackOverflow2013",
    "EnablePooling": true,
    "IntegratedAuth": false,
    "Login": "sa",
    "MaxPoolSize": 2,
    "Password": "MySqlLoginStrongPassword",
    "Server": "localhost"
  },
  "MainQuery": "EXEC dbo.usp_RandomQ;",
  "NumIterations": 50,
  "NumThreads": 2,
  "ParamDbConnectionInfo": {
    "ApplicationIntent": 0,
    "ConnectTimeout": 0,
    "Database": "",
    "EnablePooling": true,
    "IntegratedAuth": false,
    "Login": "sa",
    "MaxPoolSize": 0,
    "Password": "MySqlLoginStrongPassword",
    "Server": "localhost"
  },
  "ParamMappings": [
  ],
  "ParamQuery": "",
  "ShareDbSettings": true
}
```


## Run the load

```
# Run workload with 6 threads
sqlstresscmd -s sample.json -t 6

sqlstresscmd help

```

