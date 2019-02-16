
unit class Torch is export;

# default support json format, import :role if you want yourself configuration
role Config { ... }
# default configuration format
class JSON { ... }
class Searcher { ... }

# application configuration path
has IO  $.path;
# application name
has Str $.name is required;
# configuration type object
has $.type;
has $!cs;

submethod TWEAK() {
    # current we using ~/AppData/Local/ on Windows, other os is ~/.config/
    sub determind-local-path() {
        given $*KERNEL {
            when /win32/ {
                return $*HOME.add('AppData/Local/');
            }
            default {
                return $*HOME.add('.config/');
            }
        }
    }
    $!type = $!type // JSON;
    $!path = $!path // &determind-local-path();
    $!cs   = Searcher.new(name => $!name, path => $!path);
}

multi method load(--> Promise) {
    start {
        my @config;
        if $!cs.e {
            await supply {
                whenever $!cs.search($!type) {
                    @config.push(.self);
                }
            }
        }
        @config
    }
}

multi method load(Regex $r --> Promise) {
    start {
        my @config;
        if $!cs.e {
            await supply {
                whenever $!cs.search($!type, $r) {
                    @config.push(.self);
                }
            }
        }
        @config
    }
}

multi method Supply(--> Supply) {
    supply {
        whenever $!cs.e {
            whenever $!cs.search($!type) {
                .emit;
            }
        }
    }
}

multi method Supply(Regex $r --> Supply) {
    supply {
        whenever $!cs.e {
            whenever $!cs.search($!type, $r) {
                .emit;
            }
        }
    }
}

role Config {
    # configuration file path
    has $.path;
    # configuration name
    has $.name;

    method path(--> Str) { $!path }

    method name(--> Str) { $!name }

    # configuration file name without file extension
    method config-name(--> Str) {
        self.name.substr(0, self.name.rindex('.'));
    }

    method Str(--> Str) {
        self.path() ~ '/' ~ self.name();
    }

    method slurp(--> Str) {
        self.Str().IO.slurp;
    }

    method spurt(Str $str) {
        self.Str().IO.spurt($str);
    }

    method load()  { ... }

    method config() { ... }

    method save($config) { ... }
}

class JSON does Config {
    has %!cache;

    method load() {
        %!cache = Rakudo::Internals::JSON.from-json(self.slurp());
        %!cache;
    }

    method config() {
        %!cache;
    }

    method save($config) {
        self.spurt(Rakudo::Internals::JSON.to-json(%$config));
    }
}

class Searcher {
    has IO  $.path;
    has Str $.name is required;
    has $!config-path;

    submethod TWEAK(:$path, :$create-if-not-exists) {
        $!path = $path // $path.IO;
        $!config-path = $!path.add($!name);
        $!config-path.mkdir if $create-if-not-exists && ! $!config-path.e;
    }

    method e() {
        return $!config-path ~~ :e;
    }

    multi method search($config) {
        self!do-search($config, { $_ ne "." && $_ ne ".." });
    }

    multi method search($config, Regex $regex) {
        self!do-search($config, $regex);
    }

    method !do-search(Config $config, $r --> Supply) {
        supply {
            my @dirs = $!config-path;
            while +@dirs > 0 {
                my $dir = @dirs.shift;
                for $dir.dir -> $f {
                    if $f ~~ :d {
                        @dirs.push($f);
                    }
                    elsif $f.basename ~~ $r {
                        emit $config.new( path => $dir.path, name => $f.basename );
                    }
                }
            }
        }
    }
}
