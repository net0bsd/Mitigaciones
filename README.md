# Mitigaciones CVE-2026-31431 ("Copy Fail")

Colección de scripts y playbooks de automatización para la detección y mitigación de la vulnerabilidad CVE-2026-31431 (escalación de privilegios locales mediante corrupción del *page cache* en binarios setuid) en sistemas Linux.

## Contenido del Repositorio

* **`cve-2026-31431-mitigator.sh`**: Script interactivo en Bash puro para auditar y aplicar mitigaciones en caliente (bloqueo de módulos `algif_aead` y `authencesn` vía modprobe). Diseñado con detección automática para las familias Red Hat, SUSE y Debian.
* **`mitigar_cve.yml`**: Playbook de Ansible para el despliegue automatizado de la mitigación estricta (estándar CIS) en flotas de servidores. Ideal para infraestructuras de misión crítica (RHEL, CentOS, Oracle Linux, Fedora, AlmaLinux, Rocky Linux).

## Uso

### Script Bash (Auditoría/Mitigación local)
Ejecutar con privilegios de superusuario:
```bash
chmod +x cve-2026-31431-mitigator.sh
sudo ./cve-2026-31431-mitigator.sh

* **`rsyslog-sre-golden-signals.sh`**: Script para configurar Rsyslog, mapeando los eventos del sistema hacia las cuatro "Golden Signals" de SRE (Tráfico, Errores, Latencia, Saturación) y estableciendo el reenvío a un servidor central.
