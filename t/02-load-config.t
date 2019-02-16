
use Test;
use Torch;

plan 13;

{
    my $torch = Torch.new(name => "torch", path => './t/'.IO);
    my @configs = await $torch.load();

    is +@configs, 2, 'Load configuration ok!';
    is @configs[0].path, './t/torch', 'check configuration path ok!';
    is @configs[1].path, './t/torch', 'check configuration path ok!';
}

{
    my $torch = Torch.new(name => "torch", path => './t/'.IO);


    react {
        whenever $torch.Supply {
            is .path, './t/torch', 'check configuration path ok!';
            is .name, 'plugins.json' | 'app.json', 'check configuration name ok';
            is .config-name, 'plugins' | 'app', 'check configuration name ok';
        }
    }
}

{
    my $torch = Torch.new(name => "torch", path => './t/'.IO);
    my @configs = await $torch.load(/ 'plugin' .* /);

    is +@configs, 1, 'Load configuration ok!';
    is @configs[0].path, './t/torch', 'check configuration path ok!';
    is @configs[0].name, 'plugins.json', 'check configuration name ok!';
    is @configs[0].config-name, 'plugins', 'check configuration name ok!';
}
