#!/usr/bin/env bash

# Removing any existing virtual environment
echo "Removing existing virtual environment..."
rm -rf venv

# Adding ~/.local/bin to PATH
echo "Adding ~/.local/bin to PATH..."
export PATH=$HOME/.local/bin:$PATH

# Check if ensurepip is available
python3 -m ensurepip --version &> /dev/null
if [ $? -ne 0 ]; then
  echo "ensurepip not available, manually installing pip..."
  curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
  python3 get-pip.py --user
  export PATH=$HOME/.local/bin:$PATH
fi

# Installing virtualenv manually if necessary
if ! command -v virtualenv &> /dev/null; then
  echo "virtualenv not found, installing virtualenv..."
  pip install --user virtualenv
  export PATH=$HOME/.local/bin:$PATH
fi

# Creating a new virtual environment using virtualenv
echo "Creating virtual environment using virtualenv..."
virtualenv venv
if [ $? -ne 0 ]; then
  echo "Failed to create virtual environment"
  exit 1
fi

# Activating the virtual environment
echo "Activating virtual environment..."
if [ -f "venv/bin/activate" ]; then
  source venv/bin/activate
elif [ -f "venv/Scripts/activate" ]; then
  source venv/Scripts/activate
else
  echo "Error: venv activation script not found."
  exit 1
fi

# Check if the virtual environment is activated
if [ -z "$VIRTUAL_ENV" ]; then
  echo "Virtual environment is not activated."
  exit 1
fi

# Upgrade pip and install dependencies
echo "Upgrading pip and installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Verify that beautifulsoup4 is installed
echo "Verifying beautifulsoup4 installation..."
pip show beautifulsoup4
if [ $? -ne 0 ]; then
  echo "beautifulsoup4 is not installed."
  exit 1
fi

# Install Node.js directly if not available
if ! command -v node &> /dev/null; then
  echo "Node.js not found, installing Node.js"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install 18
  nvm use 18
fi

# Ensure Node.js version is set correctly
export PATH=$NVM_DIR/versions/node/v18.*/bin:$PATH

# Ensure frontend directory exists and restore npm packages
if [ -d "frontend" ]; then
  echo "Restoring npm packages in frontend directory..."

  # Clear npm cache
  npm cache clean --force

  # Remove existing node_modules directory
  rm -rf frontend/node_modules

  cd frontend
  npm install || (echo "Failed to restore frontend npm packages. See above for logs." && exit 1)
  cd ..
else
  echo "Frontend directory not found"
fi

# Ensure the application directory exists and change to it
cd /home/site/wwwroot || exit

# Verify that the application can import BeautifulSoup
echo "Verifying BeautifulSoup import..."
python3 -c "from bs4 import BeautifulSoup; print('BeautifulSoup import successful')"
if [ $? -ne 0 ]; then
  echo "Failed to import BeautifulSoup."
  exit 1
fi
