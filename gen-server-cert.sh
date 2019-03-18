#! /bin/bash

export PATH=$PATH:~/bin

mkdir certfile
cd certfile
mkdir etcd0 etcd1 etcd2

cat > ca-config.json << EOF1
{
    "signing": {
        "default": {
            "expiry": "10h"
        },
        "profiles": {
            "server": {
                "expiry": "100h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "1000h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "peer": {
                "expiry": "10000h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            }
        }
    }
}
EOF1

cat > ca-csr.json << EOF2
{
    "CN": "etcd-cluster",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "O": "jizhi"
        }
    ]
}
EOF2

cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

cd etcd0

cat > server.json << EOF2
{
    "CN": "etcd0",
    "hosts": [
        "127.0.0.1",
        "localhost",
        "10.5.0.10",
        "etcd0",
        "host-etcd0"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "O": "jizhi"
        }
    ]
}
EOF2
cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=server server.json | cfssljson -bare server

cd ../etcd1/
cat > server.json << EOF2
{
    "CN": "etcd1",
    "hosts": [
        "127.0.0.1",
        "localhost",
        "10.5.0.20",
        "etcd1",
        "host-etcd1"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "O": "jizhi"
        }
    ]
}
EOF2
cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=server server.json | cfssljson -bare server
cd ../etcd2/
cat > server.json << EOF2
{
    "CN": "etcd2",
    "hosts": [
        "127.0.0.1",
        "localhost",
        "10.5.0.30",
        "etcd2",
        "host-etcd2"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "O": "jizhi"
        }
    ]
}
EOF2
cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=server server.json | cfssljson -bare server

