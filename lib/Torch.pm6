
unit class Torch is export;

# default support json format, import :role if you want yourself configuration
role Config { ... }
# default configuration format
class JSON { ... }
class Searcher { ... }

has IO  $.path;
has Str $.name is required;
has $.type;
has %!config;
has $!cs;

submethod TWEAK() {
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

multi method load($config --> Promise) {
    my $p  = Promise.new;
    my $v  = $p.vow;

    %!config = %{};
    start {
        if $!cs.e {
            my $s = supply {
                whenever $!cs.search($config) {
                    %!config{.config-name} = .self;
                }
            };
            await $s;

        }
        $v.keep($!cs.e);
    }

    return $p;
}

multi method load($config, Regex $r --> Promise) {
    my $p  = Promise.new;
    my $v  = $p.vow;

    %!config = %{};
    start {
        if $!cs.e {
            my $s = supply {
                whenever $!cs.search($config, $r) {
                    %!config{.config-name} = .self;
                }
            };
            await $s;
        }
        $v.keep($!cs.e);
    }
    return $p;
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

method config() {
    %!config;
}

role Config {
    has $.path;
    has $.name;

    method path() { $!path }

    method name() { $!name }

    method config-name() {
        self.name.substr(0, self.name.rindex('.'));
    }

    method Str() {
        self.path() ~ '/' ~ self.name();
    }

    method slurp() {
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
