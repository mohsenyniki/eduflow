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

# install python packages including dbt
# doing this in the dockerfile means it only installs once during build
# not on every container restart like _PIP_ADDITIONAL_REQUIREMENTS does
# install airflow providers and data packages first
RUN pip install --no-cache-dir \
    confluent-kafka==2.3.0 \
    pandas==2.2.2 \
    pyarrow==16.0.0 \
    boto3==1.34.0 \
    sqlalchemy==1.4.52 \
    psycopg2-binary==2.9.9 \
    apache-airflow-providers-apache-spark==4.1.3

# install dbt separately to avoid dependency conflicts
RUN pip install --no-cache-dir \
    dbt-core==1.8.9 \
    dbt-postgres==1.8.2