# 这是我的Dockerfile
FROM alpine

#给镜像加个标签
LABEL maintainer="leifengyang @ dd" \
abc=def \
aaa=bbb cccc=ddd   

#运行的指令，安装了软件，修改了文件，默认是用id=0 也就是root，这个基础系统的root用户
#代表镜像构建过程中运行的命令。
RUN echo 11111


#镜像启动如果要运行很长命令才行，容器启动执行的命令
##1、准备一个sh文件，让镜像启动运行sh文件（大多镜像操作）
##2、直接在CMD的位置写即可
CMD sleep 10;echo success

