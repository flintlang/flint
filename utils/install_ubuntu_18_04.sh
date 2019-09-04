sudo apt install nodejs npm clang z3

if ! hash mono; then
  ## Mono - https://www.mono-project.com/download/stable/
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
  echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" \
    | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
  sudo apt update
  sudo apt install mono-devel
else
  echo "Found: mono"
fi

if ! hash swiftenv; then
  ## Swiftenv - https://swiftenv.fuller.li/en/latest/installation.html
  git clone https://github.com/kylef/swiftenv.git ~/.swiftenv
  echo 'export SWIFTENV_ROOT="$HOME/.swiftenv"' >> ~/.bashrc
  echo 'export PATH="$SWIFTENV_ROOT/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(swiftenv init -)"' >> ~/.bashrc
else
  echo "Found: swiftenv"
fi

cd $HOME

## Use -jN for multi-core speedup (N >= 2)
git clone --recurse-submodule https://github.com/flintlang/flint.git "~/.flint"
cd "~/.flint"
npm install
## No need iff swiftenv has already installed relevent swift version or not using swiftenv
swiftenv install
swift package update

make release

mkdir bash
echo "export PATH=$HOME/.flint/.build/release/:$PATH" >> ~/.bashrc
source ~/.bashrc