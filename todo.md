# TODO List for KAG Gather Bot

## Current TODO:

- Finish mysql data storage conversion
    - Finish converting substitution models and logic
    - Finish converting ban/report/ignore models and logic
    - Fix unit tests to use testing DB so that they can run
- Finish bot 2.0, which is bot that controls match logic, adds WARMUP mode, removes need to !end, etc
    - Make tests to ensure multiple threads can be used to manage multiple games without locking mysql connections
    - Ensure if a rcon listener thread fails the bot can continue on as normal (fail supervision)
- Fix bug where when user leaves it doesn't remove, and leaves blank name in list
    - This is due to authname check on_leaving, needs to be smarter
    - MySQL conversion should add possible workaround routes w/o having to poll entire chan periodically

## Future Additions/TODO:

- Figure out a better way to handle AFK rather than polling queue members every 2 minutes; was lagging bot signficantly
    - Consider everytime an !add/!rem is done doing afk polling
- Add !start support for server-specific matches
- Better ban system other than just X reports == ban
    - time-based bans
    - report decay
    - !ignorelist, who is ignored and reason
    - !ignore authname hours reason
    - cache ignore list in ignore plugin to prevent having to do lots of queries
- REST server for stats support (use Sinatra)
    - Make easily accessible via API
