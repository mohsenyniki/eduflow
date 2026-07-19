FROM apache/airflow:2.9.1

USER root

RUN apt-get update && \
    apt-get install -y default-jdk curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV SPARK_VERSION=3.5.1
ENV SPARK_HOME=/opt/spark

RUN curl -O https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    chmod -R 755 ${SPARK_HOME}

ENV PATH=$PATH:${SPARK_HOME}/bin
ENV JAVA_HOME=/usr/lib/jvm/default-java

USER airflow

ENV PATH=$PATH:${SPARK_HOME}/bin
ENV JAVA_HOME=/usr/lib/jvm/default-java