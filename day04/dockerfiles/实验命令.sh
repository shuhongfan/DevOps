#传入构建参数
docker build --no-cache --build-arg param="11 22 33" msg="aa bb cc" -t demo:test -f Dockerfile4 .


#进入容器控制台
docker exec -it mydemo1 /bin/sh






