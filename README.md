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

![image](https://user-images.githubusercontent.com/38274684/176166080-de211527-42b5-4088-83b3-a6fd89ef145c.png)

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

## API

> `API` Directory 하에 있는 내용입니다

공장 업체로 재고 생산을 위한 요청을 할 때 사용하게 되는 API
공장 업체와 협의되어 정리된 REST api 설명문서를 웹사이트에서 조회 할 수 있도록 `redoc-cli`를 이용하여 제작

Dockerfile을 이용하여 EC2 상에 `index.html`을 업로드하여 확인 가능

### How to Show API

```
# yaml 파일을 redoc-cli로 html파일로 만들어준다
[local] $ redoc-cli build openapi.yaml

# ec2를 만들고, ec2에다 Dockerfile과 만들어진 index.html을 scp를 통해 옮겨준다
[local] $ scp -i ./pj3key.pem Dockerfile ubuntu@13.125.238.3:/home/ubuntu/Dockerfile
[local] $ scp -i ./pj3key.pem index.html ubuntu@13.125.238.3:/home/ubuntu/index.html

# ec2에 접속한다
[ec2] $ ssh -i "pj3key.pem" ubuntu@ec2-13-125-238-3.ap-northeast-2.compute.amazonaws.com

# ec2에서 docker를 설치해준다
# https://docs.docker.com/engine/install/ubuntu/
# 해당 레퍼런스를 보고 ubuntu에 docker 설치

# ubuntu에서 sudo없이 명령어를 실행하기 위해 다음 명령어 실행
[ec2] $ sudo groupadd docker
[ec2] $ sudo usermod -aG docker $USER

# 로컬 쉘에서 ec2의 이미지를 빌드하고 run 해준다
[local] $ ssh -i "pj3key.pem" ubuntu@ec2-13-125-238-3.ap-northeast-2.compute.amazonaws.com 'docker build -t seongah:latest .'
[local] $ ssh -i "pj3key.pem" ubuntu@ec2-13-125-238-3.ap-northeast-2.compute.amazonaws.com 'docker run -d -p 8081:80 seongah:latest'

# 컨테이너가 실행됐는지 확인
[local] $ ssh -i "pj3key.pem" ubuntu@ec2-13-125-238-3.ap-northeast-2.compute.amazonaws.com 'docker ps'

ec2에서 보안그룹 인바운드 규칙에 8081을 설정 해줘야 한다

접속은 ec2 퍼블릭 dns주소에다가 포트를 추가해야 접속 가능
http://ec2-13-125-238-3.ap-northeast-2.compute.amazonaws.com:8081/
```