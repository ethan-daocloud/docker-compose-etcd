# etcd certs

[follow this steps](https://github.com/ethan-daocloud/docker-compose-etcd/tree/peer-cert):

1. fix-ip --> 固定容器ip和主机名，便于生成证书
2. server-cert --> 使用服务器端证书
3. client-cert --> 使用客户端证书
4. peer-cert --> 使用节点间证书

### 问题： 添加了证书之后连接失败

```log
[root@host-etcd-visitor /]# curl --cacert /certfile/ca.pem https://10.5.0.10:2379/v2/keys/foo -XPUT -d value=bar -v
* About to connect() to 10.5.0.10 port 2379 (#0)
*   Trying 10.5.0.10...
* Connected to 10.5.0.10 (10.5.0.10) port 2379 (#0)
* Initializing NSS with certpath: sql:/etc/pki/nssdb
*   CAfile: /certfile/ca.pem
  CApath: none
* Server certificate:
* 	subject: CN=etcd0,O=jizhi
* 	start date: Mar 18 05:24:00 2019 GMT
* 	expire date: Mar 22 09:24:00 2019 GMT
* 	common name: etcd0
* 	issuer: CN=etcd-cluster,O=jizhi
* NSS error -12276 (SSL_ERROR_BAD_CERT_DOMAIN)
* Unable to communicate securely with peer: requested domain name does not match the server's certificate.
* Closing connection 0
curl: (51) Unable to communicate securely with peer: requested domain name does not match the server's certificate.
```

原因：添加证书时没有把服务器ip添加进去，导致认证失败，相应ip添加进去即可，docker-compose 提供的服务名也要添加进去

### 问题：  client certificate not found (nickname not specified)

```log
matrix@matrix-vm:~/workspace/github/docker-compose-etcd$ docker exec -it docker-compose-etcd_etcd-visitor_1 bash
[root@host-etcd-visitor /]# curl --cacert /certfile/ca.pem https://etcd1:2379/v2/keys/foo -XPUT -d value=bar -v
* About to connect() to etcd1 port 2379 (#0)
*   Trying 10.5.0.20...
* Connected to etcd1 (10.5.0.20) port 2379 (#0)
* Initializing NSS with certpath: sql:/etc/pki/nssdb
*   CAfile: /certfile/ca.pem
  CApath: none
* NSS: client certificate not found (nickname not specified)
* NSS error -12271 (SSL_ERROR_BAD_CERT_ALERT)
* SSL peer cannot verify your certificate.
* Closing connection 0
curl: (58) NSS: client certificate not found (nickname not specified)
```

原因，没有添加客户端证书，添加客户端证书再访问就ok了，其实这个不是问题，本来就是要达到这种效果

最后访问成功

```log
[root@host-etcd-visitor /]# curl --cacert /certfile/ca.pem --cert /certfile/client.pem --key /certfile/client-key.pem https://etcd1:2379/v2/keys/foo -XPUT -d value=bar -v
* About to connect() to etcd1 port 2379 (#0)
*   Trying 10.5.0.20...
* Connected to etcd1 (10.5.0.20) port 2379 (#0)
* Initializing NSS with certpath: sql:/etc/pki/nssdb
*   CAfile: /certfile/ca.pem
  CApath: none
* NSS: client certificate from file
* 	subject: CN=etcd-client,O=jizhi
* 	start date: Mar 18 06:51:00 2019 GMT
* 	expire date: Apr 28 22:51:00 2019 GMT
* 	common name: etcd-client
* 	issuer: CN=etcd-cluster,O=jizhi
* SSL connection using TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
* Server certificate:
* 	subject: CN=etcd1,O=jizhi
* 	start date: Mar 18 06:47:00 2019 GMT
* 	expire date: Mar 22 10:47:00 2019 GMT
* 	common name: etcd1
* 	issuer: CN=etcd-cluster,O=jizhi
> PUT /v2/keys/foo HTTP/1.1
> User-Agent: curl/7.29.0
> Host: etcd1:2379
> Accept: */*
> Content-Length: 9
> Content-Type: application/x-www-form-urlencoded
> 
* upload completely sent off: 9 out of 9 bytes
< HTTP/1.1 200 OK
< Content-Type: application/json
< X-Etcd-Cluster-Id: 8fd95ce30f013867
< X-Etcd-Index: 74
< X-Raft-Index: 95
< X-Raft-Term: 52
< Date: Mon, 18 Mar 2019 07:03:45 GMT
< Content-Length: 167
< 
{"action":"set","node":{"key":"/foo","value":"bar","modifiedIndex":74,"createdIndex":74},"prevNode":{"key":"/foo","value":"bar","modifiedIndex":70,"createdIndex":70}}
* Connection #0 to host etcd1 left intact
```

### 问题1

```log
etcd2_1         | 2019-03-18 07:39:27.889054 I | embed: rejected connection from "10.5.0.20:53916" (error "tls: first record does not look like a TLS handshake", ServerName "")
etcd2_1         | 2019-03-18 07:39:27.889180 I | embed: rejected connection from "10.5.0.20:53912" (error "tls: first record does not look like a TLS handshake", ServerName "")
etcd0_1         | 2019-03-18 07:39:27.889240 I | embed: rejected connection from "10.5.0.20:36602" (error "tls: first record does not look like a TLS handshake", ServerName "")
etcd0_1         | 2019-03-18 07:39:27.889275 I | embed: rejected connection from "10.5.0.20:36598" (error "tls: first record does not look like a TLS handshake", ServerName "")
etcd1_1         | 2019-03-18 07:39:27.889514 I | embed: rejected connection from "10.5.0.30:44772" (error "tls: first record does not look like a TLS handshake", ServerName "")
etcd2_1         | 2019-03-18 07:39:27.907327 I | embed: rejected connection from "10.5.0.10:39090" (error "tls: first record does not look like a TLS handshake", ServerName "")
etcd2_1         | 2019-03-18 07:39:27.907947 I | embed: rejected connection from "10.5.0.10:39092" (error "tls: first record does not look like a TLS handshake", ServerName "")
```

解决： 由etcd的历史数据造成的，重置（清空）etcd集群的数据即可，删除数据volume，简单粗暴： docker-compose down -v [参考](https://github.com/etcd-io/etcd/issues/9917)

### 问题2

```log
etcd1_1         | 2019-03-18 07:46:45.181127 I | embed: rejected connection from "10.5.0.10:40482" (error "remote error: tls: bad certificate", ServerName "etcd1")
etcd1_1         | 2019-03-18 07:46:45.185189 I | embed: rejected connection from "10.5.0.10:40488" (error "remote error: tls: bad certificate", ServerName "etcd1")
etcd2_1         | 2019-03-18 07:46:45.186493 I | embed: rejected connection from "10.5.0.20:58316" (error "remote error: tls: bad certificate", ServerName "etcd2")
etcd2_1         | 2019-03-18 07:46:45.189980 I | embed: rejected connection from "10.5.0.20:58320" (error "remote error: tls: bad certificate", ServerName "etcd2")
etcd2_1         | 2019-03-18 07:46:45.191756 I | embed: rejected connection from "10.5.0.10:43478" (error "remote error: tls: bad certificate", ServerName "etcd2")
etcd2_1         | 2019-03-18 07:46:45.191864 I | embed: rejected connection from "10.5.0.10:43486" (error "remote error: tls: bad certificate", ServerName "etcd2")
etcd0_1         | 2019-03-18 07:46:45.192205 I | embed: rejected connection from "10.5.0.20:41012" (error "remote error: tls: bad certificate", ServerName "etcd0")
etcd0_1         | 2019-03-18 07:46:45.195983 I | embed: rejected connection from "10.5.0.20:41014" (error "remote error: tls: bad certificate", ServerName "etcd0")
```

解决： ca-config.json 里面的peer profile需要有 "server auth", 和 "client auth"，缺一不可

最后调用成功

```log
# docker exec -it docker-compose-etcd_etcd-visitor_1 bash
[root@host-etcd-visitor /]# curl --cacert /certfile/ca.pem --cert /certfile/client.pem --key /certfile/client-key.pem https://etcd1:2379/v2/members | python -m json.tool 
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   347  100   347    0     0   2647      0 --:--:-- --:--:-- --:--:--  2669
{
    "members": [
        {
            "clientURLs": [
                "https://etcd1:2379"
            ],
            "id": "1f6fd35e3327767a",
            "name": "etcd1",
            "peerURLs": [
                "https://etcd1:2380"
            ]
        },
        {
            "clientURLs": [
                "https://etcd2:2379"
            ],
            "id": "4acd0a1e9189cd7a",
            "name": "etcd2",
            "peerURLs": [
                "https://etcd2:2380"
            ]
        },
        {
            "clientURLs": [
                "https://etcd0:2379"
            ],
            "id": "ce2d9673302aa346",
            "name": "etcd0",
            "peerURLs": [
                "https://etcd0:2380"
            ]
        }
    ]
}
```

### 主要参考文档

[Security model](https://coreos.com/etcd/docs/latest/op-guide/security.html)

[Generate self-signed certificates](https://coreos.com/os/docs/latest/generate-self-signed-certificates.html)

### 参考文档

[Provide static IP to docker containers via docker-compose](https://stackoverflow.com/questions/39493490/provide-static-ip-to-docker-containers-via-docker-compose)

[How Do I Set Hostname in Docker Compose?](https://stackoverflow.com/questions/29924843/how-do-i-set-hostname-in-docker-compose)

[Remove a named volume with docker-compose?](https://stackoverflow.com/questions/45511956/remove-a-named-volume-with-docker-compose)
