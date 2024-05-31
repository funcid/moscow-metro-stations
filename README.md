# Moscow Metro Stations ETL

Этот проект выполняет извлечение, преобразование, и загрузку (ETL) данных о станциях Москвы из API Правительства Москвы (https://data.mos.ru/developers/documentation) и вставляет их в PostgreSQL базу данных с использованием Docker Compose.

## Предварительные требования

Убедитесь, что у вас установлены следующие инструменты:

- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)

Замените `YOUR_API_KEY_HERE` в .env файле на ваш актуальный API ключ. Его можно получить
на сайте Правительства Москвы - https://data.mos.ru/personal-profile/profile.
![Получение API ключа](/misc/api_key.png)

## Запуск проекта

1. Клонируйте репозиторий:
```sh
git clone https://github.com/funcid/moscow-metro-stations-etl.git
cd moscow-metro-stations-etl
```

2. Запустите контейнеры:
```sh
docker-compose up
```