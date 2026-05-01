git clone https://github.com/boz48681-collab/phb-panel-1.0.1

curl -sL https://deb.nodesource.com/setup_23.x | sudo bash -

apt-get install nodejs git

cd phb-panel-1.0.1

apt install zip -y && unzip panel.zip

 npm install && npm run seed && npm run createUser

 node .
