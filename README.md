# FactoAuto

<div align="center">
<p>DevOps 부트캠프 3번째 프로젝트</p>
<img src="https://img.shields.io/badge/AmazonAWS-232F3E?style=flat-square&logo=AmazonAWS&logoColor=white"/>
<img src="https://img.shields.io/badge/Node.js-339933?style=flat-square&logo=Node.js&logoColor=white"/>
<img src="https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=MySQL&logoColor=white"/>
<img src="https://img.shields.io/badge/AWSLambda-FF9900?style=flat-square&logo=AWSLambda&logoColor=white"/>
<img src="https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=Terraform&logoColor=white"/>
</div>

## Summary

#### 공장 자동 재고 확보 시스템 개발 프로젝트
고객이 주문 버튼을 눌렀을 때 창고의 재고 여부에 따라 재고가 있다면 구매 완료, 재고가 부족하면 제조 공장에 알려 재고를 채우는 서비스 입니다.

## Architecture

### Scenario

```
1. 소비자가 구매 API를 요청하면 Sale Lambda가 실행되어 RDS에 재고가 있는지 확인한 후 판매한다. 
1.5. 이 때, 판매가 된다면 RDS에서 재고의 수량이 -1 된다.
2. 만약 RDS에서 재고가 없다면 'Sale Lambda'는 'stock-empty' SNS를 사용하여 재고가 없다고 메세지를 보낸다.
3. 보내진 메세지는 'stock-queue' SQS로 전달된다.
3.5. 대기열의 메세지 중 오류로 인해서 보내지 못한 메세지는 DLQ로 간다. 
4. 정상적으로 보내진 메시지들은 'stock-empty' Lambda를 통해  factory API로 주문을 요청한다.
5. factory API는 'Callback URL'의 정보에 해당하는 API Gateway를 통해 'stock-inc-lambda' Lambda 함수로 재고 생산을 요청한다.
6. 'stock-inc-lambda' 함수는 재고를 10개 생산하여 RDS에 +10만큼 재고를 업데이트한다
```

## Installation

위 프로젝트는 `terraform`으로 IaC된 프로젝트 입니다.
`FACTOAUTO/terraform` 디렉토리로 이동 후 다음 명령어를 실행해 줍니다

```shell
$ terraform init
$ terraform apply
```

## How to Use

1. 구매 요청을 할 수 있는 API Gateway로 POST 요청을 보낸다

    ```
    curl --location --request POST 'YOUR SEND API GATEWAY URL' --header 'Content-Type: application/json' --data-raw '{   "MessageGroupId": "stock-empty-group",    "subject": "부산도너츠",  "message": "재고 부족",    "MessageAttributeProductId": "CP-502101",    "MessageAttributeFactoryId": "FF-500293"}'
    ```

2. 재고에 따라 다음과 같은 응답을 받을 수 있다
    - 재고가 있는 경우
    ```
    Status Code : 200
    { message: "판매완료" }
    ```
    - 재고가 없는 경우
    ```
    Status Code : 200
    { message: "재고부족, 제품 생산 요청!" }
    ```

3. 재고가 없는 경우에는 SNS로 다음과 같은 형태의 메세지를 Factory에 보내게 된다
    ```
    {
    MessageGroupId: 'stock-empty-group',
    subject: '부산도너츠',
    message: '재고 부족',
    MessageAttributeProductId: 'CP-502101',
    MessageAttributeFactoryId: 'FF-500293'
    }
    {
    ResponseMetadata: { RequestId: '0f04d709-0794-55b0-b46d-8ded54771137' },
    MessageId: 'f66b9d13-4749-5c9b-895e-c7f714aa881c'
    }
    ```

4. Factory에서 재고 생산이 완료되면 RDS에 10개의 재고가 추가로 쌓이고, 고객이 구매 요청을 보냈을 때 2번의 재고가 있는 경우의 메세지를 받을 수 있다