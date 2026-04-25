#!/usr/bin/env bash
#
# DataLog Development Setup Script
# =================================
# Automatically checks dependencies and sets up the development environment
#
# Usage: ./scripts/setup-dev.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Banner
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   DataLog Development Setup Script    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check OS
print_header "System Information"
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*)    MACHINE=Cygwin;;
    MINGW*)     MACHINE=MinGw;;
    *)          MACHINE="UNKNOWN:${OS}"
esac
print_info "Operating System: ${MACHINE}"
print_info "Shell: $SHELL"

# Check Ruby
print_header "Checking Ruby"
if check_command ruby; then
    RUBY_VERSION=$(ruby --version)
    print_success "Ruby installed: $RUBY_VERSION"

    RUBY_VER=$(ruby -e 'puts RUBY_VERSION')
    if [[ "$(printf '%s\n' "3.0" "$RUBY_VER" | sort -V | head -n1)" == "3.0" ]]; then
        print_success "Ruby version is 3.0 or higher"
    else
        print_error "Ruby version 3.0+ required, found $RUBY_VER"
        print_info "Install Ruby 3.2+ using rbenv or rvm"
        exit 1
    fi
else
    print_error "Ruby not found"
    print_info "Install Ruby 3.2+ from https://www.ruby-lang.org/en/documentation/installation/"
    exit 1
fi

# Check Bundler
if check_command bundle; then
    BUNDLER_VERSION=$(bundle --version)
    print_success "Bundler installed: $BUNDLER_VERSION"
else
    print_warning "Bundler not found. Installing..."
    gem install bundler
    print_success "Bundler installed"
fi

# Check Node.js
print_header "Checking Node.js"
if check_command node; then
    NODE_VERSION=$(node --version)
    print_success "Node.js installed: $NODE_VERSION"

    NODE_VER=$(node -e 'console.log(process.versions.node)')
    NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
    if [[ "$NODE_MAJOR" -ge 18 ]]; then
        print_success "Node.js version is 18 or higher"
    else
        print_error "Node.js version 18+ required, found v$NODE_VER"
        print_info "Install Node.js 18+ from https://nodejs.org/"
        exit 1
    fi
else
    print_error "Node.js not found"
    print_info "Install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

# Check npm
if check_command npm; then
    NPM_VERSION=$(npm --version)
    print_success "npm installed: v$NPM_VERSION"
else
    print_error "npm not found"
    exit 1
fi

# Check Python
print_header "Checking Python"
if check_command python3; then
    PYTHON_VERSION=$(python3 --version)
    print_success "Python installed: $PYTHON_VERSION"
else
    print_warning "Python 3 not found"
    print_info "Python is optional but recommended for Jupyter notebook support"
    print_info "Install from https://www.python.org/"
fi

# Check Git
print_header "Checking Git"
if check_command git; then
    GIT_VERSION=$(git --version)
    print_success "Git installed: $GIT_VERSION"
else
    print_error "Git not found"
    print_info "Install Git from https://git-scm.com/"
    exit 1
fi

# Check optional dependencies
print_header "Checking Optional Dependencies"

if check_command docker; then
    print_success "Docker installed (optional)"
else
    print_info "Docker not found (optional, for containerized development)"
fi

# Install Ruby dependencies
print_header "Installing Ruby Dependencies"
print_info "Running: bundle install"
if bundle install; then
    print_success "Ruby dependencies installed"
else
    print_error "Failed to install Ruby dependencies"
    exit 1
fi

# Install Node.js dependencies
print_header "Installing Node.js Dependencies"
print_info "Running: npm ci"
if npm ci; then
    print_success "Node.js dependencies installed"
else
    print_error "Failed to install Node.js dependencies"
    exit 1
fi

# Install Python dependencies (if Python is available)
if check_command python3; then
    print_header "Installing Python Dependencies"
    print_info "Running: pip install -r requirements.txt"
    if python3 -m pip install --upgrade pip --quiet && python3 -m pip install -r requirements.txt --quiet; then
        print_success "Python dependencies installed"
    else
        print_warning "Failed to install Python dependencies (non-critical)"
    fi
fi

# Set up Husky hooks
print_header "Setting Up Git Hooks"
if [ -f "package.json" ] && grep -q "\"prepare\"" package.json; then
    print_info "Running: npm run prepare"
    if npm run prepare; then
        print_success "Git hooks installed (Husky)"
    else
        print_warning "Failed to set up git hooks"
    fi
fi

# Create .env file if it doesn't exist
print_header "Environment Setup"
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    print_info "Creating .env file from .env.example"
    cp .env.example .env
    print_success ".env file created"
    print_warning "Remember to configure environment variables in .env"
else
    print_info ".env file already exists"
fi

# Run security audit
print_header "Security Audit"
print_info "Running: npm audit"
npm audit || print_warning "Some security vulnerabilities found. Run 'npm audit fix' to resolve."

# Build assets
print_header "Building Assets"
print_info "Building JavaScript bundles"
if npm run build:js; then
    print_success "JavaScript assets built"
else
    print_warning "Failed to build JavaScript assets"
fi

# Test the setup
print_header "Testing Setup"
print_info "Running unit tests"
if npm run test; then
    print_success "Unit tests passed"
else
    print_error "Unit tests failed"
    exit 1
fi

# Summary
print_header "Setup Complete! 🎉"
echo ""
print_success "All dependencies installed and configured"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Review environment variables in .env"
echo "  2. Start development server: ${GREEN}bundle exec jekyll serve${NC}"
echo "  3. View site at: ${GREEN}http://localhost:4000${NC}"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  • Run tests:           ${GREEN}npm run test${NC}"
echo "  • Run with coverage:   ${GREEN}npm run test:coverage${NC}"
echo "  • Build JavaScript:    ${GREEN}npm run build:js${NC}"
echo "  • Build site:          ${GREEN}bundle exec jekyll build${NC}"
echo "  • Run linter:          ${GREEN}npm run lint${NC} (if configured)"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  • README.md                    - Getting started"
echo "  • docs/environment-setup.md    - Environment configuration"
echo "  • docs/scripts-reference.md    - Scripts documentation"
echo "  • CONTRIBUTING.md              - Contribution guidelines"
echo ""
print_success "Happy coding! 🚀"
echo ""
