#!/bin/bash

# Получаем переменные окружения
API_KEY=$API_KEY
PG_HOST=$POSTGRES_HOST
PG_PORT=$POSTGRES_PORT
PG_DB=$POSTGRES_DB
PG_USER=$POSTGRES_USER
PG_PASSWORD=$POSTGRES_PASSWORD

# Убедимся, что все переменные окружения заданы
if [[ -z "$API_KEY" || -z "$PG_HOST" || -z "$PG_PORT" || -z "$PG_DB" || -z "$PG_USER" || -z "$PG_PASSWORD" ]]; then
    echo "Не все переменные окружения заданы!"
    exit 1
fi

# Выполняем запрос через curl
RESPONSE=$(curl -s "https://apidata.mos.ru/v1/datasets/624/rows?api_key=${API_KEY}")

# Проверяем ответ
if [[ -z "$RESPONSE" ]]; then
    echo "Не удалось получить ответ от API"
    exit 1
fi

# Пробуем подключиться к базе данных и создать таблицу
psql postgresql://$PG_USER:$PG_PASSWORD@$PG_HOST:$PG_PORT/$PG_DB <<EOF
CREATE TABLE IF NOT EXISTS moscow_station_data (
    global_id BIGINT PRIMARY KEY,
    number INT,
    name VARCHAR,
    on_territory_of_moscow VARCHAR,
    adm_area VARCHAR,
    district VARCHAR,
    longitude_wgs84 DOUBLE PRECISION,
    latitude_wgs84 DOUBLE PRECISION,
    vestibule_type VARCHAR,
    name_of_station VARCHAR,
    line VARCHAR,
    cultural_heritage_site_status VARCHAR,
    mode_on_even_days VARCHAR,
    mode_on_odd_days VARCHAR,
    full_featured_bpa_amount INT,
    little_functional_bpa_amount INT,
    bpa_amount INT,
    repair_of_escalators JSON,
    object_status VARCHAR,
    geo_data JSON
);

EOF

# Подготовка данных для многозначной вставки
insert_values=""
echo "${RESPONSE}" | jq -c '.[]' | while IFS= read -r element; do
    global_id=$(echo "${element}" | jq '.global_id')
    number=$(echo "${element}" | jq '.Number')
    name=$(echo "${element}" | jq -r '.Cells.Name | @sh')
    on_territory_of_moscow=$(echo "${element}" | jq -r '.Cells.OnTerritoryOfMoscow | @sh')
    adm_area=$(echo "${element}" | jq -r '.Cells.AdmArea | @sh')
    district=$(echo "${element}" | jq -r '.Cells.District | @sh')
    longitude_wgs84=$(echo "${element}" | jq -r '.Cells.Longitude_WGS84')
    latitude_wgs84=$(echo "${element}" | jq -r '.Cells.Latitude_WGS84')
    vestibule_type=$(echo "${element}" | jq -r '.Cells.VestibuleType | @sh')
    name_of_station=$(echo "${element}" | jq -r '.Cells.NameOfStation | @sh')
    line=$(echo "${element}" | jq -r '.Cells.Line | @sh')
    cultural_heritage_site_status=$(echo "${element}" | jq -r '.Cells.CulturalHeritageSiteStatus | @sh')
    mode_on_even_days=$(echo "${element}" | jq -r '.Cells.ModeOnEvenDays | @sh')
    mode_on_odd_days=$(echo "${element}" | jq -r '.Cells.ModeOnOddDays | @sh')
    full_featured_bpa_amount=$(echo "${element}" | jq '.Cells.FullFeaturedBPAAmount')
    little_functional_bpa_amount=$(echo "${element}" | jq '.Cells.LittleFunctionalBPAAmount')
    bpa_amount=$(echo "${element}" | jq '.Cells.BPAAmount')
    repair_of_escalators=$(echo "${element}" | jq -c '.Cells.RepairOfEscalators // "[]"')
    object_status=$(echo "${element}" | jq -r '.Cells.ObjectStatus | @sh')
    geo_data=$(echo "${element}" | jq -c '.Cells.geoData')

    # Убедимся, что строковые значения правильно экранированы для SQL
    name=$(printf "%s" "$name" | sed "s/'/''/g")
    on_territory_of_moscow=$(printf "%s" "$on_territory_of_moscow" | sed "s/'/''/g")
    adm_area=$(printf "%s" "$adm_area" | sed "s/'/''/g")
    district=$(printf "%s" "$district" | sed "s/'/''/g")
    vestibule_type=$(printf "%s" "$vestibule_type" | sed "s/'/''/g")
    name_of_station=$(printf "%s" "$name_of_station" | sed "s/'/''/g")
    line=$(printf "%s" "$line" | sed "s/'/''/g")
    cultural_heritage_site_status=$(printf "%s" "$cultural_heritage_site_status" | sed "s/'/''/g")
    mode_on_even_days=$(printf "%s" "$mode_on_even_days" | sed "s/'/''/g")
    mode_on_odd_days=$(printf "%s" "$mode_on_odd_days" | sed "s/'/''/g")
    object_status=$(printf "%s" "$object_status" | sed "s/'/''/g")

    # Добавляем значения к запросу на вставку
    insert_values="$insert_values ($global_id, $number, '$name', '$on_territory_of_moscow', '$adm_area', '$district', $longitude_wgs84, $latitude_wgs84, '$vestibule_type', '$name_of_station', '$line', '$cultural_heritage_site_status', '$mode_on_even_days', '$mode_on_odd_days', $full_featured_bpa_amount, $little_functional_bpa_amount, $bpa_amount, '$repair_of_escalators', '$object_status', '$geo_data'),"
done

# Удаляем последнюю запятую
insert_values=${insert_values%,}

# Выполняем вставку всех данных одним запросом
if [ -n "$insert_values" ]; then
    psql -q postgresql://$PG_USER:$PG_PASSWORD@$PG_HOST:$PG_PORT/$PG_DB <<EOF
    INSERT INTO moscow_station_data (
        global_id, number, name, on_territory_of_moscow, adm_area, district,
        longitude_wgs84, latitude_wgs84, vestibule_type, name_of_station, line,
        cultural_heritage_site_status, mode_on_even_days, mode_on_odd_days,
        full_featured_bpa_amount, little_functional_bpa_amount, bpa_amount,
        repair_of_escalators, object_status, geo_data
    )
    VALUES
    $insert_values
    ON CONFLICT (global_id) DO NOTHING;
EOF
fi

# Выводим текущее количество записей в таблице после вставки данных
final_count=$(psql -Atc "SELECT count(*) FROM moscow_station_data;" postgresql://$PG_USER:$PG_PASSWORD@$PG_HOST:$PG_PORT/$PG_DB)
echo "Количество записей после вставки: $final_count"

echo "Скрипт выполнен успешно!"