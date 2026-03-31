#!/bin/bash

#===============================================================================
# Script Name: server-stats.sh
# Description: Analyse complète des performances serveur Linux
# Author: Server Admin
# Date: $(date +%Y-%m-%d)
#===============================================================================

#-------------------------------------------------------------------------------
# Configuration et couleurs
#-------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SEPARATOR="================================================================================"

#-------------------------------------------------------------------------------
# Fonctions utilitaires
#-------------------------------------------------------------------------------
print_header() {
    echo -e "\n${BOLD}${BLUE}${SEPARATOR}${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}${SEPARATOR}${NC}\n"
}

print_info() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

#-------------------------------------------------------------------------------
# 1. Utilisation CPU Totale
#-------------------------------------------------------------------------------
get_cpu_usage() {
    print_header "UTILISATION CPU"
    
    # Méthode 1: Utilisation via /proc/stat (plus précis)
    local cpu_stats=$(grep '^cpu ' /proc/stat)
    local cpu_user=$(echo $cpu_stats | awk '{print $2}')
    local cpu_nice=$(echo $cpu_stats | awk '{print $3}')
    local cpu_system=$(echo $cpu_stats | awk '{print $4}')
    local cpu_idle=$(echo $cpu_stats | awk '{print $5}')
    local cpu_iowait=$(echo $cpu_stats | awk '{print $6}')
    local cpu_irq=$(echo $cpu_stats | awk '{print $7}')
    local cpu_softirq=$(echo $cpu_stats | awk '{print $8}')
    
    local cpu_total=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq))
    local cpu_used=$((cpu_user + cpu_nice + cpu_system + cpu_irq + cpu_softirq))
    
    if [ $cpu_total -ne 0 ]; then
        local cpu_percent=$(awk "BEGIN {printf \"%.2f\", ($cpu_used / $cpu_total) * 100}")
    else
        local cpu_percent="0.00"
    fi
    
    # Méthode 2: Utilisation via top (instantanée)
    local top_cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    echo -e "${CYAN}Statistiques CPU:${NC}"
    echo -e "  Utilisation calculée: ${BOLD}${cpu_percent}%${NC}"
    echo -e "  Utilisation top:      ${BOLD}${top_cpu}%${NC}"
    echo -e "  Cœurs disponibles:    ${BOLD}$(nproc)${NC}"
    
    # Load Average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo -e "  Load Average (1/5/15 min):${BOLD}${load_avg}${NC}"
}

#-------------------------------------------------------------------------------
# 2. Utilisation Mémoire
#-------------------------------------------------------------------------------
get_memory_usage() {
    print_header "UTILISATION MÉMOIRE"
    
    # Lecture des infos mémoire
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    local buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
    local cached=$(grep ^Cached /proc/meminfo | awk '{print $2}')
    
    # Calculs en KB puis conversion en GB
    local mem_used=$((mem_total - mem_available))
    local mem_percent=$(awk "BEGIN {printf \"%.2f\", ($mem_used / $mem_total) * 100}")
    
    local total_gb=$(awk "BEGIN {printf \"%.2f\", $mem_total / 1024 / 1024}")
    local used_gb=$(awk "BEGIN {printf \"%.2f\", $mem_used / 1024 / 1024}")
    local free_gb=$(awk "BEGIN {printf \"%.2f\", $mem_available / 1024 / 1024}")
    
    # Affichage barre de progression visuelle
    local bar_length=50
    local filled_length=$(awk "BEGIN {printf \"%d\", ($mem_percent / 100) * $bar_length}")
    local bar=$(printf "%0.s█" $(seq 1 $filled_length))
    local empty=$(printf "%0.s░" $(seq 1 $((bar_length - filled_length))))
    
    echo -e "${CYAN}Mémoire RAM:${NC}"
    echo -e "  [${GREEN}${bar}${NC}${empty}] ${BOLD}${mem_percent}%${NC}"
    echo -e "  Total: ${BOLD}${total_gb} GB${NC}"
    echo -e "  Utilisée: ${BOLD}${used_gb} GB${NC} (${mem_percent}%)"
    echo -e "  Disponible: ${BOLD}${free_gb} GB${NC}"
    
    # Swap
    local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    if [ $swap_total -gt 0 ]; then
        local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
        local swap_used=$((swap_total - swap_free))
        local swap_percent=$(awk "BEGIN {printf \"%.2f\", ($swap_used / $swap_total) * 100}")
        local swap_total_gb=$(awk "BEGIN {printf \"%.2f\", $swap_total / 1024 / 1024}")
        local swap_used_gb=$(awk "BEGIN {printf \"%.2f\", $swap_used / 1024 / 1024}")
        
        echo -e "\n${CYAN}Swap:${NC}"
        echo -e "  Total: ${BOLD}${swap_total_gb} GB${NC}"
        echo -e "  Utilisé: ${BOLD}${swap_used_gb} GB${NC} (${swap_percent}%)"
    fi
}

#-------------------------------------------------------------------------------
# 3. Utilisation Disque
#-------------------------------------------------------------------------------
get_disk_usage() {
    print_header "UTILISATION DISQUE"
    
    echo -e "${CYAN}Points de montage principaux:${NC}"
    echo -e "${BOLD}%-20s %10s %10s %10s %8s %s${NC}" "Filesystem" "Size" "Used" "Avail" "Use%" "Mounted on"
    echo -e "--------------------------------------------------------------------------------"
    
    df -h | grep -E '^/dev/' | while read filesystem size used avail percent mount; do
        # Coloration selon le pourcentage d'utilisation
        local usage_num=${percent%\%}
        if [ $usage_num -ge 90 ]; then
            local color=$RED
        elif [ $usage_num -ge 70 ]; then
            local color=$YELLOW
        else
            local color=$GREEN
        fi
        
        printf "%-20s %10s %10s %10s ${color}%8s${NC} %s\n" "$filesystem" "$size" "$used" "$avail" "$percent" "$mount"
    done
    
    # Total usage
    local total_disk=$(df / | tail -1 | awk '{print $2}')
    local used_disk=$(df / | tail -1 | awk '{print $3}')
    local avail_disk=$(df / | tail -1 | awk '{print $4}')
    local disk_percent=$(df / | tail -1 | awk '{print $5}')
    
    echo -e "\n${CYAN}Résumé Root (/) :${NC}"
    echo -e "  Total: ${BOLD}${total_disk}${NC}"
    echo -e "  Utilisé: ${BOLD}${used_disk}${NC} (${disk_percent})"
    echo -e "  Disponible: ${BOLD}${avail_disk}${NC}"
    
    # Inodes
    echo -e "\n${CYAN}Utilisation des inodes:${NC}"
    df -i / | tail -1 | awk '{
        printf "  Total: %s | Utilisés: %s | Disponibles: %s | Utilisation: %s\n", $2, $3, $4, $5
    }'
}

#-------------------------------------------------------------------------------
# 4. Top 5 Processus par CPU
#-------------------------------------------------------------------------------
get_top_cpu_processes() {
    print_header "TOP 5 PROCESSUS PAR UTILISATION CPU"
    
    echo -e "${BOLD}%-8s %-10s %-8s %-8s %s${NC}" "PID" "USER" "%CPU" "%MEM" "COMMAND"
    echo -e "--------------------------------------------------------------------------------"
    
    ps aux --sort=-%cpu | head -6 | tail -5 | while read user pid cpu mem vsz rss tty stat start time command; do
        printf "%-8s %-10s ${YELLOW}%-8s${NC} %-8s %s\n" "$pid" "$user" "$cpu" "$mem" "$command"
    done
}

#-------------------------------------------------------------------------------
# 5. Top 5 Processus par Mémoire
#-------------------------------------------------------------------------------
get_top_memory_processes() {
    print_header "TOP 5 PROCESSUS PAR UTILISATION MÉMOIRE"
    
    echo -e "${BOLD}%-8s %-10s %-8s %-8s %s${NC}" "PID" "USER" "%CPU" "%MEM" "COMMAND"
    echo -e "--------------------------------------------------------------------------------"
    
    ps aux --sort=-%mem | head -6 | tail -5 | while read user pid cpu mem vsz rss tty stat start time command; do
        printf "%-8s %-10s %-8s ${CYAN}%-8s${NC} %s\n" "$pid" "$user" "$cpu" "$mem" "$command"
    done
}

#-------------------------------------------------------------------------------
# Stretch Goals - Informations Système
#-------------------------------------------------------------------------------
get_system_info() {
    print_header "INFORMATIONS SYSTÈME"
    
    # OS Version
    if [ -f /etc/os-release ]; then
        local os_name=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
        echo -e "${CYAN}OS Version:${NC} ${BOLD}${os_name}${NC}"
    else
        echo -e "${CYAN}OS Version:${NC} ${BOLD}$(uname -o)${NC}"
    fi
    
    # Kernel
    echo -e "${CYAN}Kernel:${NC}     ${BOLD}$(uname -r)${NC}"
    
    # Architecture
    echo -e "${CYAN}Architecture:${NC} ${BOLD}$(uname -m)${NC}"
    
    # Uptime
    local uptime_info=$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes"}')
    echo -e "${CYAN}Uptime:${NC}     ${BOLD}${uptime_info}${NC}"
    
    # Utilisateurs connectés
    local logged_users=$(who | wc -l)
    echo -e "${CYAN}Utilisateurs connectés:${NC} ${BOLD}${logged_users}${NC}"
    
    # Adresse IP principale
    local ip_address=$(hostname -I | awk '{print $1}')
    echo -e "${CYAN}IP Address:${NC} ${BOLD}${ip_address}${NC}"
    
    # Hostname
    echo -e "${CYAN}Hostname:${NC}   ${BOLD}$(hostname)${NC}"
}

#-------------------------------------------------------------------------------
# Stretch Goals - Sécurité
#-------------------------------------------------------------------------------
get_security_info() {
    print_header "INFORMATIONS DE SÉCURITÉ"
    
    # Tentatives de connexion échouées (si journalctl disponible)
    if command -v journalctl &> /dev/null; then
        local failed_ssh=$(journalctl _SYSTEMD_UNIT=sshd.service 2>/dev/null | grep -c "Failed password" || echo "0")
        echo -e "${CYAN}Tentatives SSH échouées (aujourd'hui):${NC} ${BOLD}${failed_ssh}${NC}"
    fi
    
    # Dernières connexions
    echo -e "\n${CYAN}Dernières connexions réussies:${NC}"
    last -5 | grep -v "^$" | head -5 | while read line; do
        echo -e "  ${line}"
    done
    
    # Sessions actives
    echo -e "\n${CYAN}Sessions actuelles:${NC}"
    who | while read line; do
        echo -e "  ${GREEN}●${NC} ${line}"
    done
}

#-------------------------------------------------------------------------------
# Stretch Goals - Statistiques Réseau
#-------------------------------------------------------------------------------
get_network_stats() {
    print_header "STATISTIQUES RÉSEAU"
    
    # Interfaces réseau
    echo -e "${CYAN}Interfaces actives:${NC}"
    ip -brief addr show | grep -v "^lo" | while read line; do
        echo -e "  ${line}"
    done
    
    # Connexions réseau actives
    local established=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || ss -t state established 2>/dev/null | wc -l)
    local listening=$(netstat -tln 2>/dev/null | grep LISTEN | wc -l || ss -tln 2>/dev/null | wc -l)
    
    echo -e "\n${CYAN}Connexions:${NC}"
    echo -e "  Établies:  ${BOLD}${established}${NC}"
    echo -e "  En écoute: ${BOLD}${listening}${NC}"
}

#-------------------------------------------------------------------------------
# Fonction principale
#-------------------------------------------------------------------------------
main() {
    clear
    echo -e "${BOLD}${GREEN}"
    cat << "EOF"
   _____                            _       _             
  / ____|                          | |     | |            
 | (___   ___ _ ____   _____ _ __  | | __ _| |_ ___ _ __  
  \___ \ / _ \ '__\ \ / / _ \ '__| | |/ _` | __/ _ \ '__| 
  ____) |  __/ |   \ V /  __/ |    | | (_| | ||  __/ |    
 |_____/ \___|_|    \_/ \___|_|    |_|\__,_|\__\___|_|    
                                                          
EOF
    echo -e "${NC}"
    echo -e "${SEPARATOR}"
    echo -e "Rapport généré le: ${BOLD}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${SEPARATOR}"
    
    # Vérification des permissions
    if [ "$EUID" -ne 0 ]; then 
        print_warning "Exécution sans privilèges root - certaines informations peuvent être limitées"
    fi
    
    # Exécution de toutes les fonctions
    get_system_info
    get_cpu_usage
    get_memory_usage
    get_disk_usage
    get_top_cpu_processes
    get_top_memory_processes
    get_network_stats
    get_security_info
    
    print_header "FIN DU RAPPORT"
}

#-------------------------------------------------------------------------------
# Gestion des arguments
#-------------------------------------------------------------------------------
show_help() {
    echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --cpu       Afficher uniquement l'utilisation CPU"
    echo "  -m, --memory    Afficher uniquement l'utilisation mémoire"
    echo "  -d, --disk      Afficher uniquement l'utilisation disque"
    echo "  -p, --process   Afficher uniquement les top processus"
    echo "  -n, --network   Afficher uniquement les stats réseau"
    echo "  -s, --security  Afficher uniquement les infos de sécurité"
    echo "  -h, --help      Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0              # Rapport complet"
    echo "  $0 --cpu        # Uniquement CPU"
    echo "  $0 -m -d        # Mémoire et Disque"
}

# Parse arguments
case "$1" in
    -c|--cpu)
        get_cpu_usage
        ;;
    -m|--memory)
        get_memory_usage
        ;;
    -d|--disk)
        get_disk_usage
        ;;
    -p|--process)
        get_top_cpu_processes
        get_top_memory_processes
        ;;
    -n|--network)
        get_network_stats
        ;;
    -s|--security)
        get_security_info
        ;;
    -h|--help)
        show_help
        ;;
    "")
        main
        ;;
    *)
        print_error "Option invalide: $1"
        show_help
        exit 1
        ;;
esac