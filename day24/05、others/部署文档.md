以后*.itdachang.com这个通配符证书，各个名称空间都放一份

```sh
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=*.itdachang.com/O=*.itdachang.com"
```







# 1、Harbor

私有镜像仓库，保存docker的images的

## 1、创建基本信息

```sh
kubectl create ns devops
#提前
kubectl create secret tls itdachang.com --cert=tls.crt   --key=tls.key  -n devops
```



## 2、部署harbor

```yaml
# 下载
helm repo add harbor https://helm.goharbor.io
helm pull harbor/harbor

# 修改配置  vi  overvalue.yaml
expose:  #web浏览器访问用的证书
  type: ingress
  tls:
    certSource: "secret"
    secret:
      secretName: "itdachang.com"
      notarySecretName: "itdachang.com"
  ingress:
    hosts:
      core: harbor.itdachang.com
      notary: notary-harbor.itdachang.com
externalURL: https://harbor.itdachang.com
internalTLS:  #harbor内部组件用的证书
  enabled: true
  certSource: "auto"
persistence:
  enabled: true
  resourcePolicy: "keep"
  persistentVolumeClaim:
    registry:  # 存镜像的
      storageClass: "rook-ceph-block"
      accessMode: ReadWriteOnce
      size: 5Gi
    chartmuseum: #存helm的chart
      storageClass: "rook-ceph-block"
      accessMode: ReadWriteOnce
      size: 5Gi
    jobservice: #
      storageClass: "rook-ceph-block"
      accessMode: ReadWriteOnce
      size: 1Gi
    database: #数据库  pgsql
      storageClass: "rook-ceph-block"
      accessMode: ReadWriteOnce
      size: 1Gi
    redis: #
      storageClass: "rook-ceph-block"
      accessMode: ReadWriteOnce
      size: 1Gi
    trivy: # 漏洞扫描
      storageClass: "rook-ceph-block"
      accessMode: ReadWriteOnce
      size: 5Gi
metrics:
  enabled: true
```



```sh
# 部署
helm install -f values.yaml  -f override.yaml  harbor ./ -n devops
```



## 3、部署完成

```sh
kubectl get pod -n devops

```



访问： https://harbor.itdachang.com:4443/

默认访问账号密码：admin   Harbor12345



参照使用： https://goharbor.io/docs/2.2.0/working-with-projects/create-projects/





## 4、推送与下载镜像

```sh
docker login  aliyunxxxx
## 给所有docker机器 配置/etc/hosts       
10.120.102.31 harbor.itdachang.com
192.168.0.14 harbor.itdachang.com
## 给vpc网络配置443转到任意一个ingress机器的443
以后任意域名直接配置  
vpcip（不能访问443？？？） 域名地址  
192.168.0.14 harbor.itdachang.com


docker login harbor.itdachang.com
```

> 自定义域名（使用自签证书）docker不能信任证书

```sh
docker pull busybox
docker tag busybox harbor.itdachang.com/mall/busybox:v1.0
docker push  harbor.itdachang.com/mall/busybox:v1.0
```

> 各个docker节点都应该信任这个证书





## 5、使用私有仓库与镜像代理

> 机器人账号
>
> admin Harbor12345
>
> 机器人：
>
> 账号： robot$hello+hellopull
>
> 密码： foTlux0RTBGzPlvNaxmAkEj4E6quYb10
>
> 



```sh
docker tag busybox harbor.itdachang.com/hello/busybox:v1.0
```

代理仓库，代理中央仓库

```sh
#代理官方镜像
docker pull harbor.itdachang.com/hello/library/alpine
#代理第三方
docker pull harbor.itdachang.com/hello/nginx/nginx-ingress
```



> webhook：钩子
>
> 可以结合cicd。触发外界行为







# 2、jenkins

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: jenkins
  namespace: devops
spec:
  selector:
    matchLabels:
      app: jenkins # has to match .spec.template.metadata.labels
  serviceName: "jenkins"
  replicas: 1
  template:
    metadata:
      labels:
        app: jenkins # has to match .spec.selector.matchLabels
    spec:
      serviceAccountName: "jenkins"
      terminationGracePeriodSeconds: 10
      containers:
      - name: jenkins
        image: jenkinsci/blueocean:1.24.7
        securityContext:                     
          runAsUser: 0                      #设置以ROOT用户运行容器
          privileged: true                  #拥有特权
        ports:
        - containerPort: 8080
          name: web
        - name: jnlp                        #jenkins slave与集群的通信口
          containerPort: 50000
        resources:
          limits:
            memory: 2Gi
            cpu: "2000m"
          requests:
            memory: 700Mi
            cpu: "500m"
        env:
        - name: LIMITS_MEMORY
          valueFrom:
            resourceFieldRef:
              resource: limits.memory
              divisor: 1Mi
        - name: "JAVA_OPTS" #设置变量，指定时区和 jenkins slave 执行者设置
          value: " 
                   -Xmx$(LIMITS_MEMORY)m 
                   -XshowSettings:vm 
                   -Dhudson.slaves.NodeProvisioner.initialDelay=0
                   -Dhudson.slaves.NodeProvisioner.MARGIN=50
                   -Dhudson.slaves.NodeProvisioner.MARGIN0=0.75
                   -Duser.timezone=Asia/Shanghai
                 "  
        volumeMounts:
        - name: home
          mountPath: /var/jenkins_home
  volumeClaimTemplates:
  - metadata:
      name: home
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "rook-ceph-block"
      resources:
        requests:
          storage: 5Gi

---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: devops
spec:
  selector:
    app: jenkins
  type: ClusterIP
  ports:
  - name: web
    port: 8080
    targetPort: 8080
    protocol: TCP
  - name: jnlp
    port: 50000
    targetPort: 50000
    protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins
  namespace: devops
spec:
  tls:
  - hosts:
      - jenkins.itdachang.com
    secretName: itdachang.com
  rules:
  - host: jenkins.itdachang.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jenkins
            port:
              number: 8080
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: devops

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins
rules:
  - apiGroups: ["extensions", "apps"]
    resources: ["deployments"]
    verbs: ["create", "delete", "get", "list", "watch", "patch", "update"]
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["create", "delete", "get", "list", "watch", "patch", "update"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["create","delete","get","list","patch","update","watch"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create","delete","get","list","patch","update","watch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get","list","watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins
roleRef:
  kind: ClusterRole
  name: jenkins
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: devops
```

> jenkins有些插件在线下载不来。手动下载过来。放在jenkins的/var/jenkins_home/plugins文件夹中即可
>
> kubectl cp xxxx  podName:/var/jenkins_home/plugins
>
> ```sh
>   # Copy /tmp/foo local file to /tmp/bar in a remote pod in namespace <some-namespace>
>   kubectl cp /tmp/foo <some-namespace>/<some-pod>:/tmp/bar
>   
>   # Copy /tmp/foo from a remote pod to /tmp/bar locally
>   kubectl cp <some-namespace>/<some-pod>:/tmp/foo /tmp/bar
> ```
>
> 

账号密码：admin  Admin123

```sh
https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json
```





















