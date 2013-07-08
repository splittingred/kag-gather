# KAG Gather

An IRC bot that does matchmaking, statistics, and achievements for the KAG Gather community.

http://gather.kag2d.nl

## Installation

Create a database called `kag_gather`, and then copy config/config.sample.json to config.json. Edit the values within
to setup the bot.

Then run

`bundle install`

To setup the ruby gems needed. Finally, run:

`rake db:migrate`

To create the SQL tables needed.

## Usage

Run to start the bot:

`./bin/kag-gather &`

Run to start the stats REST server:

`./bin/kag-server &`
