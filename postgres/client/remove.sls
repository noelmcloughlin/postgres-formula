{%- from "postgres/map.jinja" import postgres with context -%}

#remove PG version
{%- set releases = [ postgres.version, ] %}

#or remove PG versions
{% if postgres.purge.all %}
  {%- set releases = postgres.upstream.releases %}
{% endif %}

# software removal
{%- for release in releases %}

  {% if 'bin_dir' in postgres %}
    {%- for bin in postgres.client_bins %}
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
    - require_in:
      - pkg: postgresql{{ release }}-client-pkgs-removed
    {%- endfor %}
  {%- endif %}

postgresql{{ release }}-client-pkgs-removed:
  pkg.purged:
    - pkgs:
      - postgresql
      - postgresql{{ release }}-common
      - postgresql{{ release }}-jdbc
      - postgresql{{ release }}
      - postgresql{{ release|replace('.', '') }}
      - postgresql-{{ release }}
      - postgresql-{{ release|replace('.', '') }}

{% endfor %}

# Remove dev packages
{% if postgres.purge.all %}

postgresql-client-dev-removed:
  pkg.purged:
    - pkgs:
      {% if postgres.pkg_dev %}
      - {{ postgres.pkg_dev }}
      {% endif %}
      {% if postgres.pkg_libpq_dev %}
      - {{ postgres.pkg_libpq_dev }}
      - libpq5
      - libpqxx
      {% endif %}
      {% if postgres.pkg_python %}
      - {{ postgres.pkg_python }}
      {% endif %}
      {# other packages #}
      - libpostgresql-jdbc-java
      - postgresql-client-common

{% endif %}

