FROM sqitch/sqitch:latest
COPY . /repo
WORKDIR /repo
# O comando usa variáveis de ambiente injetadas pelo compose
CMD sqitch deploy db:pg://${DB_USER}:${DB_PASS}@db/${DB_NAME}
