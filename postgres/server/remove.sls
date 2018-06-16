{%- from "postgres/map.jinja" import postgres with context %}

#purge PG version
{% set releases = [ postgres.version, ] %}

#or purge all PG versions
{% if postgres.purge.all %}
  {% set releases = postgres.upstream.releases %}
{% endif %}

postgresql-dead:
  service.dead:
    - name: {{ postgres.service }}
    - enable: False

postgresql-repo-removed:
  pkgrepo.absent:
    - name: {{ postgres.pkg_repo.name }}
    {%- if 'pkg_repo_keyid' in postgres %}
    - keyid: {{ postgres.pkg_repo_keyid }}
    {%- endif %}

{% for release in releases %}

postgresql{{ release }}-server-pkgs-removed:
  pkg.purged:
    - pkgs:
      - postgresql
      - postgresql-server
      - postgresql-libs
      - postgresql-server-{{ release }}
      - postgresql-libs-{{ release }}
      - postgresql-contrib-{{ release }}
      - postgresql{{ release }}-contrib
      - postgresql{{ release }}-server
      - postgresql{{ release }}-libs
      - postgresql{{ release }}-contrib
      - postgresql{{ release|replace('.', '') }}-contrib
      - postgresql{{ release|replace('.', '') }}-server
      - postgresql{{ release|replace('.', '') }}-libs
      - postgresql{{ release|replace('.', '') }}-contrib

  {% if 'bin_dir' in postgres %}
    {% for bin in postgres.server_bins %}
      {% set path = '/usr/pgsql-' + release|string + '/bin/' + bin %}
postgresql{{ release }}-{{ bin }}-alts-remove:
  alternatives.remove:
    - name: {{ bin }}
    - path: {{ path }}
      {% if grains.os in ('Fedora', 'CentOS',) %}
      {# bypass bug #}
    - onlyif: alternatives --display {{ bin }}
      {% else %}
    - onlyif: test -f {{ path }}
      {% endif %}
    {% endfor %}
  {% endif %}

{% endfor %}

postgresql-dataconf-removed:
  file.absent:
    - names:
      - {{ postgres.conf_dir }}
      - {{ postgres.data_dir }}
  {% if postgres.purge.all %}    
      - /var/lib/postgresql
      - /var/lib/pgsql
  {% endif %}

  {% for name, tblspace in postgres.tablespaces|dictsort() %}
postgresql-tablespace-dir-{{ name }}-removed:
  file.absent:
    - name: {{ tblspace.directory }}
    - require:
      - file: postgresql-dataconf-removed
  {% endfor %}

