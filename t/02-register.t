
use Test;
use Canoe;
use lib './t/lib';

plan 19;

my @config;

given Canoe.new(file => './t/plugin.json') {
    unless .e {
        await .create;
    }
    @config = await .load();

    is +@config, 1, 'Load plugin configuration file ok!';
    is @config[0].name, 'Test::Plugin1', 'Check plugin name ok!';
    is @config[0].enable, True, 'Plugin 1 is enabled!';
    is @config[0].installed, True, 'Load Plugin 1 ok!';
    is (await .disable(@config[0].name)), True, 'disable Plugin 1';
    is (await .register('Test::Plugin2', True)), True, 'Register plugin ok!';
    is (await .register('Test::Plugin3', True)), True, 'Register plugin ok!';
    @config = await .load();

    is @config[0].enable, False, 'Plugin 1 is not enabled!';
    is (await .enable(@config[0].name)), True, 'enable Plugin 1';

    is +@config, 3, 'Load plugin configuration file ok!';
    is @config[1].name, 'Test::Plugin2', 'Check plugin name ok!';
    is @config[1].enable, True, 'Plugin 2 is enabled!';
    is @config[1].installed, True, 'Load Plugin 2 ok!';

    is @config[2].name, 'Test::Plugin3', 'Check plugin name ok!';
    is @config[2].enable, True, 'Plugin 3 is enabled!';
    is @config[2].installed, False, 'Plugin 3 is not installed ok!';

    is (await .unregister('Test::Plugin2')), True, 'Unregister Plugin 2 ok!';
    is (await .unregister('Test::Plugin3')), True, 'Unregister Plugin 3 ok!';
    @config = await .load();

    is +@config, 1, 'Load plugin configuration file ok!';
}
