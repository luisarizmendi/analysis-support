#!/bin/bash
psql -h analysisdb -p 5432 -U analysisadmin analysisdb  -c "CREATE SCHEMA analysis AUTHORIZATION analysisadmin;"
psql -h analysisdb -p 5432 -U analysisadmin analysisdb  -c "alter table if exists analysis.LineItems
    drop constraint if exists FK6fhxopytha3nnbpbfmpiv4xgn;"
psql -h analysisdb -p 5432 -U analysisadmin analysisdb  -c "drop table if exists analysis.LineItems cascade;
drop table if exists analysis.Orders cascade;
drop table if exists analysis.OutboxEvent cascade;"
psql -h analysisdb -p 5432 -U analysisadmin analysisdb  -c "create table analysis.LineItems (
                          itemId varchar(255) not null,
                          item varchar(255),
                          lineItemStatus varchar(255),
                          name varchar(255),
                          order_id varchar(255) not null,
                          primary key (itemId)
);"

psql -h analysisdb -p 5432 -U analysisadmin analysisdb  -c "create table analysis.Orders (
                        order_id varchar(255) not null,
                        patientId varchar(255),
                        orderStatus varchar(255),
                        timestamp timestamp,
                        primary key (order_id)
);"

psql -h analysisdb -p 5432 -U analysisadmin analysisdb  -c "create table analysis.OutboxEvent (
                            id uuid not null,
                            aggregatetype varchar(255) not null,
                            aggregateid varchar(255) not null,
                            type varchar(255) not null,
                            timestamp timestamp not null,
                            payload varchar(8000),
                            primary key (id)
);"

psql -h analysisdb -p 5432 -U analysisadmin analysisdb  -c "alter table if exists analysis.LineItems
    add constraint FK6fhxopytha3nnbpbfmpiv4xgn
        foreign key (order_id)
            references analysis.Orders;"