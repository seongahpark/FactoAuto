'use strict'

const http = require('http');

exports.handler = function(event, context){

    let newevent = JSON.parse(event.Records[0].body)
    
    const msg = {
        "MessageGroupId": 'stock-arrival-group',
        "MessageAttributeProductId": `${newevent.MessageAttributes.ProductId.Value}`,
        "MessageAttributeProductCnt": 10,
        "MessageAttributeFactoryId": `${newevent.MessageAttributes.FactoryId.Value}`,
        "MessageAttributeRequester": '박성아',
        //"CallbackUrl": 'https://gnm6ed0nph.execute-api.ap-northeast-2.amazonaws.com/send',
        "CallbackUrl": process.env.CALLBACKURL + process.env.CALLBACKURLSTAGE + '/send'
    }

    console.log(JSON.stringify(msg));
    try{
        const result = PostCode(msg);
        console.log(result);

        return {
            statusCode: 200,
            headers: {'ContentType': 'application/json'},
            body: JSON.stringify(result),
        };
    } catch (error){
        console.log(error);
        return {
            statusCode: 400,
            body: error.message,
        };
    }
}

function PostCode(post_data){
    const post_options = {
        host: 'factory.p3.api.codestates-devops.be',
        port: '8080',
        path: '/api/manufactures',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        }
    };

    const post_req = http.request(post_options, function(res){
        res.setEncoding('utf8');
        res.on('data', function (chunk) {
            console.log('Respoonse: ' + chunk)
        });
    });

    post_req.write(JSON.stringify(post_data));
    post_req.end();
}