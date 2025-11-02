#!/bin/bash
# ==================================================================================
# Shell Script for HLS-UART Vivado Project (Linux/Mac)
# ==================================================================================
# Description: Automates the entire Vivado build process
# Usage: ./run_vivado.sh
# ==================================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "HLS-UART Vivado Project Build Script"
echo -e "==========================================${NC}"
echo

# Check if Vivado is available
if ! command -v vivado &> /dev/null; then
    echo -e "${RED}ERROR: Vivado not found in PATH${NC}"
    echo "Please source Vivado settings first:"
    echo "  source /tools/Xilinx/Vivado/2019.2/settings64.sh"
    exit 1
fi

# Get Vivado version
VIVADO_VER=$(vivado -version | grep Vivado | head -1)
echo -e "${GREEN}Found: $VIVADO_VER${NC}"
echo

# Function: Create project
create_project() {
    echo
    echo -e "${BLUE}=========================================="
    echo "Creating Vivado Project..."
    echo -e "==========================================${NC}"
    vivado -mode batch -source create_uart_project.tcl
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Project created successfully!${NC}"
    else
        echo -e "${RED}ERROR: Project creation failed${NC}"
        exit 1
    fi
}

# Function: Build project
build_project() {
    echo
    echo -e "${BLUE}=========================================="
    echo "Building Vivado Project..."
    echo -e "==========================================${NC}"
    echo -e "${YELLOW}This may take 10-30 minutes depending on your system...${NC}"
    echo
    vivado -mode batch -source build_project.tcl
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Build completed successfully!${NC}"
    else
        echo -e "${RED}ERROR: Build failed${NC}"
        exit 1
    fi
}

# Function: Clean project
clean_project() {
    echo
    echo -e "${YELLOW}WARNING: This will delete the vivado_project directory${NC}"
    read -p "Are you sure? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Clean cancelled"
        return
    fi

    echo "Cleaning project..."
    rm -rf vivado_project
    rm -rf .Xil
    rm -f vivado*.jou vivado*.log
    echo -e "${GREEN}Project cleaned!${NC}"
}

# Function: Display menu
show_menu() {
    echo "Select operation:"
    echo "1. Create new project"
    echo "2. Build existing project (synthesis + implementation + bitstream)"
    echo "3. Clean project"
    echo "4. Full flow (create + build)"
    echo "5. Open Vivado GUI with project"
    echo "6. Exit"
    echo
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter choice (1-6): " choice

    case $choice in
        1)
            create_project
            ;;
        2)
            build_project
            ;;
        3)
            clean_project
            ;;
        4)
            echo
            echo -e "${BLUE}=========================================="
            echo "Running Full Flow (Create + Build)..."
            echo -e "==========================================${NC}"
            create_project
            echo
            echo "Waiting 5 seconds before starting build..."
            sleep 5
            build_project
            ;;
        5)
            if [ -f "vivado_project/hls_uart_dma.xpr" ]; then
                echo "Opening Vivado GUI..."
                vivado vivado_project/hls_uart_dma.xpr &
                echo -e "${GREEN}Vivado GUI launched${NC}"
            else
                echo -e "${RED}ERROR: Project not found${NC}"
                echo "Please create the project first (option 1)"
            fi
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac

    echo
    read -p "Press Enter to continue..."
    echo
done
