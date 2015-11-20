# Copyright 2011 MaestroDev
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Definition: plugin
#
# A puppet definition for Sonar plugin installation
#
define sonarqube::plugin(
  $version,
  $ensure     = present,
  $artifactid = $name,
  $groupid    = 'org.codehaus.sonar-plugins',
  $fetch      = {},
) {
  validate_hash($fetch)

  $plugin_name = "${artifactid}-${version}.jar"
  $plugin_path = "${sonarqube::plugin_dir}/${plugin_name}"

  # Install plugin
  if $ensure == present {

    exec { "remove-old-versions-of-${artifactid}":
      command     => "/tmp/cleanup-old-plugin-versions.sh ${sonarqube::plugin_dir} ${artifactid} ${version}",
      path        => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin',
      refreshonly => true
    }

    if empty($fetch) {

      # copy to a temp file as Maven can run as a different user and not have
      # rights to copy to sonar plugin folder
      maven { "/tmp/${plugin_name}":
        groupid    => $groupid,
        artifactid => $artifactid,
        version    => $version,
        notify     => Exec["remove-old-versions-of-${artifactid}"],
        require    => File[$sonarqube::plugin_dir],
      }
      ->
      file { $plugin_path:
        ensure => $ensure,
        source => "/tmp/${plugin_name}",
        owner  => $sonarqube::user,
        group  => $sonarqube::group,
        notify => Service['sonarqube'],
      }

    } else {

      if !(has_key($fetch, 'base_url') and has_key($fetch, 'source_hash')) {
        fail("parameter 'fetch' must have keys 'base_url' and 'source_hash'")
      }
      $base_url    = $fetch['base_url']
      $source_hash = $fetch['source_hash']

      wget::fetch { $artifactid:
        source      => "${base_url}/${plugin_name}",
        source_hash => $source_hash,
        destination => $plugin_path,
        execuser    => $sonarqube::user,
        notify => [Exec["remove-old-versions-of-${artifactid}"],
                   Service['sonarqube']],
      }

    }

  } else {
    # Uninstall plugin if absent
    file { $plugin_path:
      ensure => $ensure,
      notify => Service['sonarqube'],
    }
  }
}
