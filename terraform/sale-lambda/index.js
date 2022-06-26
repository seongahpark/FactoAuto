'use strict'
const serverless = require('serverless-http');
const express = require("express");
const app = express();

const AWS = require("aws-sdk");
// const credentials = new AWS.SharedIniFileCredentials({
//   profile: 'seongah',
// });
const sns = new AWS.SNS({ region: "ap-northeast-2" });

const port = 3000;

app.use(express.json());

app.get("/status", (req, res) => res.json({ status: "ok", sns: sns }));
app.post("/send", (req, res) => {
  var mysql = require("mysql");
  var connection = mysql.createConnection({
    // RDS에서 DB를 생성하고 연결하세요.
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  connection.query(
    `
        SELECT
            BIN_TO_UUID(product_id) as product_id
            , name, price, stock, BIN_TO_UUID(factory_id), BIN_TO_UUID(ad_id)
        FROM product
        WHERE sku = '${req.body.MessageAttributeProductId}';
        `,
    function (error, results, fields) {
      if (error) throw error;
      if (results[0].stock > 0) {
        console.log(results);
        console.log("The stock is: ", results[0].stock);
        const sql = `
                UPDATE product
                SET stock = ${results[0].stock - 1}
                WHERE product_id = UUID_TO_BIN('${results[0].product_id}');
                `;
        console.log(sql);
        connection.query(sql, function (error, results2, fields) {
          if (error) throw error;
        });
        console.log("재고 감소 !!");
        return res.status(200).send({ message: "판매완료" });
      } else {
        console.log("재고 부족 상황!!");
        console.log(req.body);
        let now = new Date().toString();
        let email = `${req.body.message} \n \n This was sent: ${now}`;
        let params = {
          Message: email,
          Subject: req.body.subject,
          MessageAttributes: {
            ProductId: {
              StringValue: req.body.MessageAttributeProductId,
              DataType: "String",
            },
            FactoryId: {
              StringValue: req.body.MessageAttributeFactoryId,
              DataType: "String",
            },
          },
          // https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SQS.html#sendMessage-property
          TopicArn: process.env.TOPIC_ARN
        };

        sns.publish(params, function (err, data) {
          if (err) console.log(err, err.stack);
          else console.log(data);
          return res.status(200).send({ message: "재고부족, 제품 생산 요청!" });
        });
      }
    }
  );
});
//app.listen(port, () => console.log(`SNS App listening on port ${port}!`));
/**
curl --location --request POST 'https://j4bfrui6qk.execute-api.ap-northeast-2.amazonaws.com/send' --header 'Content-Type: application/json' --data-raw '{   "MessageGroupId": "stock-empty-group",    "subject": "부산도너츠 재고 부 족",  "message": "재고 부족",    "MessageAttributeProductId": "CP-502101",    "MessageAttributeFactoryId": "FF-500293"}'
 * */

module.exports.handler = serverless(app);