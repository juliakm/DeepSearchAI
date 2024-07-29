#!/usr/bin/env bash

# Ensure the venv directory exists and create it if it doesn't
if [ -d "venv" ]; then
  echo "Removing existing virtual environment..."
  rm -rf venv
fi

# Use Python 3.11 to create the virtual environment
echo "Creating virtual environment using python3..."
python3 -m venv venv || { echo "Failed to create virtual environment"; exit 1; }

# Ensure pip is in the PATH
export PATH=$PATH:/home/.local/bin:/home/site/wwwroot/venv/bin

# Activate the virtual environment
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

# Install virtualenv if not available
if ! pip show virtualenv &> /dev/null; then
  echo "Installing virtualenv..."
  pip install virtualenv || { echo "Failed to install virtualenv"; exit 1; }
fi

# Create the virtual environment using virtualenv
echo "Creating virtual environment using virtualenv..."
virtualenv venv || { echo "Failed to create virtual environment with virtualenv"; exit 1; }

# Upgrade pip and install dependencies
echo "Upgrading pip and installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

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
  cd frontend
  npm cache clean --force
  rm -rf node_modules package-lock.json
  npm install
  if [ $? -ne 0 ]; then
    echo "Failed to restore frontend npm packages. See above for logs."
  fi
  cd ..
else
  echo "Frontend directory not found"
fi

# Ensure the application directory exists and change to it
cd /home/site/wwwroot || exit

# Listing directory contents for debugging
echo "Listing directory contents for debugging:"
ls -al

# Listing contents of venv/bin directory
echo "Listing contents of venv/bin directory:"
ls -al venv/bin
