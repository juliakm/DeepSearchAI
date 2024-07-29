#!/usr/bin/env bash

# Removing any existing virtual environment
echo "Removing existing virtual environment..."
rm -rf venv antenv /tmp/8dcae9a511ee18a/antenv

# Extract the pre-built virtual environment
echo "Extracting pre-built virtual environment..."
tar -xzvf venv.tar.gz

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

  # Remove existing node_modules directory and package-lock.json
  rm -rf frontend/node_modules frontend/package-lock.json

  cd frontend

  # Regenerate package-lock.json
  npm install || (echo "Failed to restore frontend npm packages. See above for logs." && exit 1)

  cd ..
else
  echo "Frontend directory not found"
fi

# Ensure the application directory exists and change to it
cd /home/site/wwwroot || exit

# Verify that the application can import BeautifulSoup
echo "Verifying BeautifulSoup import..."
python -c "from bs4 import BeautifulSoup; print('BeautifulSoup import successful')"
if [ $? -ne 0 ]; then
  echo "Failed to import BeautifulSoup."
  exit 1
fi

# Override any existing PYTHONPATH
export PYTHONPATH=/home/site/wwwroot/venv/lib/python3.11/site-packages

# Azure will Launch the application...
# python3 -m gunicorn app:app
