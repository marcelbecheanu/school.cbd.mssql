/* uma base dados só é criada quando contém uma ou mais coleções */
use WWIWeb;

/* Mostra as bases de dados criadas */
show dbs; 

/* Adicionar coleções */

db.createCollection('Customer');
db.createCollection('TaxRate');
db.createCollection('Brand');
db.createCollection('StockItem');
db.createCollection('Orders');
db.createCollection('OrderList');

/* Mostra as bases de dados criadas */
show dbs;

/*
    Importar os ficheiros JSON se tiver algum erro executar no powershell devido as variaveis de ambiente os erros podem acontecer .
    Pode ser necessario adicionar as variaveis de ambiente de forma automatica e/ou a instalação dos addons do mongo.
*/

mongoimport --jsonArray --db WWIWeb --collection Customer --file customer.json
mongoimport --jsonArray --db WWIWeb --collection TaxRate --file taxrate.json
mongoimport --jsonArray --db WWIWeb --collection Brand --file brand.json
mongoimport --jsonArray --db WWIWeb --collection StockItem --file stockitem.json
mongoimport --jsonArray --db WWIWeb --collection Orders --file orders.json
mongoimport --jsonArray --db WWIWeb --collection OrderList --file orderlist.json

/* Normalizar datas */

// Orders
db.Orders.updateMany(
  {},
  [
    {
      $set: {
        InvoiceDate: {
          $dateFromString: {
            dateString: "$InvoiceDate"
          }
        },
        OrderDate: {
          $dateFromString: {
            dateString: "$OrderDate"
          }
        }
      }
    }
  ]
)

// Customer
db.Customer.updateMany(
  {},
  [
    {
      $set: {
        CustomerUpdateAt: {
          $dateFromString: {
            dateString: "$CustomerUpdateAt"
          }
        }
    }
  ]
)

// Create Indices for better performace

db.OrderList.createIndex( { "OrderID": 1, "StockItemID": 1 } );
db.Orders.createIndex({ "OrderID": 1 });
db.StockItem.createIndex({ "StockItemID": 1 });

// Listar por Produto o “histórico de vendas” adquiridos pelo cliente;
db.StockItem.aggregate([
  {
    $lookup: {
      from: "OrderList",
      localField: "StockItemID",
      foreignField: "StockItemID",
      as: "OrderList"
    }
  },
  {
    $unwind: "$OrderList"
  },
  {
    $lookup: {
      from: "Orders",
      localField: "OrderList.OrderID",
      foreignField: "OrderID",
      as: "OrderList.Order"
    }
  },
  {
    $unwind: "$OrderList.Order"
  },
  {
      $group: {
          _id: "$_id",
          ItemName: { $first: "$ItemName"},
          OrderList: { $push: "$OrderList" }
      }
  },
  {
      $project: {
          ItemName: 1,
          OrderList: 1
      }
  }
]);
