# you_go_to_nahui
Собственно какое название, такой и результат

Плагины тут https://github.com/YOURLS/awesome#plugins устанавливать простым копированием в папку. Рекомендую mobaxterm там и терминал и файловый менеджер.


Привязываем домен на голый сервак, копируем команды, жмем ентер, указываем данные - радуемся. SSL обновляется автоматически, проверка каждый день. 
Если хочется привязать кучу доменов - выполнить: ./ssl.sh в консоли 

        curl -k -o my_script.sh https://raw.githubusercontent.com/up4k1/you_go_to_nahui/main/main1.sh

        chmod +x my_script.sh

        ./my_script.sh



Здесь моя личная подборка плагинов (в процессе)




Отдельная установка docker+docker-compose 
`apt update -y`
`apt install curl -y`
`curl -k -o ddcs.sh https://raw.githubusercontent.com/up4k1/you_go_to_nahui/main/ddcsetup.sh`
`chmod +x ddcs.sh`
`./ddcs.sh`
