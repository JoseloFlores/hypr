#!/bin/bash
# Reinicio ultra-limpio de Eww
# Usamos -x para matar solo el proceso exacto 'eww' y no este script
pkill -9 -x eww
sleep 1
/home/jose/eww/target/release/eww daemon &
sleep 1
/home/jose/eww/target/release/eww open eww-bar
/home/jose/eww/target/release/eww open solar-dashboard
