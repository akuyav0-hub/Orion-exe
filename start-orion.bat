bat
@echo off
cd /d "C:\Users\haro4\Projects\Orion\current"
start "" "http://localhost:8000/orion_phase3_4.html"
python -m http.server 8000