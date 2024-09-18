# Database

The conversation history is stored in **Cosmos DB in a Document DB API**. 

| Key             | Value                                       |
|-----------------|---------------------------------------------|
| DB              | db_conversation_history                     |
| Container name  | conversations                               |
| Partition key   | `/userId` provided by App Service easy auth |

The `conversations` container is managed by the `cosmosdbservice.py`.

```
conversation = {
    'id': str(uuid.uuid4()),  
    'type': 'conversation',
    'createdAt': datetime.utcnow().isoformat(),  
    'updatedAt': datetime.utcnow().isoformat(),  
    'userId': user_id,
    'title': title
}
```

## PowerBI reports

Reports are not available yet. In order to get any reports from PBI for this project, they need to work with a secure-by-default database. Currently Cosmos DB is used with a connection string or key from Power BI, therefore doesn't align with secure-by-default requirements. A proposed solution is to build a pipeline to pull the Cosmos DB data into a database which PBI can access with out keys or connection strings. 