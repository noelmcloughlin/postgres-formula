{%- from "postgres/map.jinja" import postgres with context %}

{%- set includes = [] %}
{%- if postgres.bake_image %}
  {%- do includes.append('postgres.server.image') %}
{%- endif %}
{%- if postgres.use_upstream_repo == true -%}
  {%- do includes.append('postgres.upstream') %}
{%- endif %}

{%- if includes -%}
include:
  {{ includes|yaml(false)|indent(2) }}
{%- endif %}

{%- set pkgs = [postgres.pkg] + postgres.pkgs_extra %}

# Install, configure and start PostgreSQL server

postgresql-server:
  pkg.installed:
    - pkgs: {{ pkgs }}
  {%- if postgres.fromrepo %}
    - fromrepo: {{ postgres.fromrepo }}
  {%- endif %}
  {%- if postgres.use_upstream_repo == true %}
    - refresh: True
    - require:
      - pkgrepo: postgresql-repo
  {%- endif %}
  {%- if grains.os == 'MacOS' %}
     #Register as Launchd LaunchAgent for system users
    - require_in:
      - file: postgresql-server
  file.managed:
    - name: /Library/LaunchAgents/{{ postgres.service }}.plist
    - source: /usr/local/opt/postgres/{{ postgres.service }}.plist
    - group: wheel
    - require_in:
      - service: postgresql-running

  {%- else %}

# Alternatives system. Make server binaries available in $PATH
    {%- if 'bin_dir' in postgres and postgres.linux.altpriority %}
      {%- for bin in postgres.server_bins %}
        {%- set path = salt['file.join'](postgres.bin_dir, bin) %}

postgresql-{{ bin }}-altinstall:
  alternatives.install:
    - name: {{ bin }}
    - link: {{ salt['file.join']('/usr/bin', bin) }}
    - path: {{ path }}
    - priority: {{ postgres.linux.altpriority }}
    - onlyif: test -f {{ path }}
    - require:
      - pkg: postgresql-server
    - require_in:
      - cmd: postgresql-cluster-prepared

      {%- endfor %}
    {%- endif %}

  {%- endif %}

postgresql-cluster-prepared:
  file.directory:
    - name: {{ postgres.data_dir }}
    - user: {{ postgres.user }}
    - group: {{ postgres.group }}
    - makedirs: True
    - recurse:
      - user
      - group
  cmd.run:
 {%- if postgres.prepare_cluster.command is defined %}
      {# support for depreciated 'prepare_cluster.command' pillar #}
    - name: {{ postgres.prepare_cluster.command }}
    - unless: {{ postgres.prepare_cluster.test }}
 {%- else %}
    - name: {{ postgres.prepare_cluster.pgcommand + ' ' }} {{ postgres.data_dir }}
    - unless: test -f {{ postgres.data_dir }}/{{ postgres.prepare_cluster.pgtestfile }}
 {%- endif %}
    - cwd: /
    - env: {{ postgres.prepare_cluster.env }}
    - runas: {{ postgres.user }} 
    - require:
      - pkg: postgresql-server
      - file: postgresql-cluster-prepared

postgresql-config-dir:
  file.directory:
    - names:
      - {{ postgres.data_dir }}
      - {{ postgres.conf_dir }}
    - user: {{ postgres.user }}
    - group: {{ postgres.group }}
<<<<<<< HEAD
    - dir_mode: 0700
=======
    - dir_mode: {{ postgres.conf_dir_mode }}
>>>>>>> feb2b38... Allow setting dir mode for conf_dir in pillar
    - force: True
    - file_mode: 644
    - recurse:
      - user
      - group
    - makedirs: True
    - require:
      - cmd: postgresql-cluster-prepared

{%- if postgres.postgresconf %}

postgresql-conf:
  file.blockreplace:
    - name: {{ postgres.conf_dir }}/postgresql.conf
    - marker_start: "# Managed by SaltStack: listen_addresses: please do not edit"
    - marker_end: "# Managed by SaltStack: end of salt managed zone --"
    - content: |
        {{ postgres.postgresconf|indent(8) }}
    - show_changes: True
    - append_if_not_found: True
    {#- Detect empty values (none, '') in the config_backup #}
    - backup: {{ postgres.config_backup|default(false, true) }}
    - require:
      - file: postgresql-config-dir
    - watch_in:
       - service: postgresql-running

{%- endif %}

{%- set pg_hba_path = salt['file.join'](postgres.conf_dir, 'pg_hba.conf') %}

postgresql-pg_hba:
  file.managed:
    - name: {{ pg_hba_path }}
    - user: {{ postgres.user }}
    - group: {{ postgres.group }}
    - mode: 600
{%- if postgres.acls %}
    - source: {{ postgres['pg_hba.conf'] }}
    - template: jinja
    - defaults:
        acls: {{ postgres.acls }}
  {%- if postgres.config_backup %}
    # Create the empty file before managing to overcome the limitation of check_cmd
    - onlyif: test -f {{ pg_hba_path }} || touch {{ pg_hba_path }}
    # Make a local backup before the file modification
    - check_cmd: >-
        salt-call --local file.copy
        {{ pg_hba_path }} {{ pg_hba_path ~ postgres.config_backup }} remove_existing=true
  {%- endif %}
{%- else %}
    - replace: False
{%- endif %}
    - require:
      - file: postgresql-config-dir

{%- set pg_ident_path = salt['file.join'](postgres.conf_dir, 'pg_ident.conf') %}

postgresql-pg_ident:
  file.managed:
    - name: {{ pg_ident_path }}
    - user: {{ postgres.user }}
    - group: {{ postgres.group }}
    - mode: 600
{%- if postgres.identity_map %}
    - source: {{ postgres['pg_ident.conf'] }}
    - template: jinja
    - defaults:
        mappings: {{ postgres.identity_map }}
  {%- if postgres.config_backup %}
    # Create the empty file before managing to overcome the limitation of check_cmd
    - onlyif: test -f {{ pg_ident_path }} || touch {{ pg_ident_path }}
    # Make a local backup before the file modification
    - check_cmd: >-
        salt-call --local file.copy
        {{ pg_ident_path }} {{ pg_ident_path ~ postgres.config_backup }} remove_existing=true
  {%- endif %}
{%- else %}
    - replace: False
{%- endif %}
    - require:
      - file: postgresql-config-dir

{%- for name, tblspace in postgres.tablespaces|dictsort() %}

postgresql-tablespace-dir-{{ name }}:
  file.directory:
    - name: {{ tblspace.directory }}
    - user: {{ postgres.user }}
    - group: {{ postgres.group }}
    - mode: 770
    - makedirs: True
    - recurse:
      - user
      - group
    - require:
      - pkg: postgresql-server

{%- endfor %}

{%- if not postgres.bake_image %}

# Start PostgreSQL server using OS init
postgresql-running:
  service.running:
    - name: {{ postgres.service }}
    - enable: True
   {% if grains.os not in ('MacOS',) %}
    - reload: True
   {% endif %}
    - watch:
      - file: postgresql-pg_hba
      - file: postgresql-pg_ident

{%- endif %}
