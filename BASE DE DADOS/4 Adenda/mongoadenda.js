
// Criar Collection
db.createCollection('LogisticTransport');

// Importar dados ou abrir script shell -- Run on shell
// mongoimport --jsonArray --db WWIWeb --collection LogisticTransport --file adenda.json

use WWIWeb;

// Atualizar Datas
db.LogisticTransport.updateMany({},
    [{
        $set: {
            "transport": {
                $map: {
                    input: "$transport",
                    as: "r",
                    in: {
                        $mergeObjects: [
                            "$$r",
                            { shippingDate: { $toDate: "$$r.shippingDate" } },
                            { deliveryDate: { $toDate: "$$r.deliveryDate" } }
                        ]
                    }
                }
            }
        }
    }]
)

// Numero medio de dias por empresa logistica
db.LogisticTransport.aggregate(
    [
        { $unwind: "$transport" },
        {
            $addFields: {
                "transport.differenceBetweenDays": {
                    $dateDiff: {
                        startDate: "$transport.shippingDate",
                        endDate: "$transport.deliveryDate",
                        unit: "day"
                    }
                }
            }  
        },
        {
            $group: {
                _id: "$name",
                transport: { $push: "$transport" },
                avgDifferenceBetweenDays: {
                    $avg: "$transport.differenceBetweenDays"
                }
            }
        },
        {
            $project: {
                _id: 0,
                name: "$_id",
                avgDifferenceBetweenDays: 1,
                transport: {
                    $map:{
                        input: "$transport",
                        as: "t",
                        in: {
                            saleID: "$$t.saleid",
                            shippingDate: "$$t.shippingDate",
                            deliveryDate: "$$t.deliveryDate",
                            differenceBetweenDays: "$$t.differenceBetweenDays"
                        }
                    }
                }
            }
        }
    ]
)

// Numero de transportes por empresa logistica
db.LogisticTransport.aggregate(
    [  
        {
            $project: {
                name: 1,
                NTransportes: {
                    $size: "$transport"
                }
            }
        }
    ]
)

// Criar a collection que vai ser utilizada para exportar.
db.LogisticTransport.aggregate(
    [  
        {
            $project: {
                name: 1,
            }
        },
        { $out : "Logistic" }
        
    ],
)

// Exportar run on shell
// mongoexport --db=WWIWeb --collection=Logistic --type=json --jsonArray --out=Logistic.json

// Apagar a collection
db.Logistic.drop()

// Criar a collection que vai ser utilizada para exportar. 

db.LogisticTransport.aggregate([
  { $unwind: "$transport" },
  {
    $project: {
      _id: 0,
      saleid: "$transport.saleid",
      name: "$name",
      shippingDate: { $dateToString: { format: "%Y-%m-%d", date: "$transport.shippingDate" }},
      deliveryDate: { $dateToString: { format: "%Y-%m-%d", date: "$transport.deliveryDate" }},
      trackingNumber: "$transport.trackingNumber"
    }
  },
  { $out : "Transport" }
])


// Exportar run on shell
// mongoexport --db=WWIWeb --collection=Transport --type=json --jsonArray --out=Transport.json

db.Transport.drop();

