/*
  Copyright 2020 The dNation Kubernetes Monitoring Authors. All Rights Reserved.
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

/* K8s node exporter dashboard */

local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local prometheus = grafana.prometheus;
local statPanel = grafana.statPanel;
local gaugePanel = grafana.gaugePanel;
local graphPanel = grafana.graphPanel;
local row = grafana.row;
local table = grafana.tablePanel;

{
  grafanaDashboards+:: {
    'node-exporter':
      local upTimePanel =
        statPanel.new(
          title='Uptime',
          datasource='$datasource',
          graphMode='none',
          decimals=0,
          unit='s',
        )
        .addTarget(prometheus.target('avg(time() - node_boot_time_seconds{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'))
        .addThreshold({ color: $._config.grafanaDashboards.color.blue, value: null });


      local ipTable =
        table.new(
          title='Table of IP Addresses',
          datasource='$datasource',
          styles=[
            { pattern: 'Time', type: 'hidden' },
            { pattern: 'Value', type: 'hidden' },
            { alias: 'Instance', pattern: '_0_nodename', type: 'string' },
            { alias: 'IP Address', pattern: '_1_instance', type: 'string' },
          ]
        )
        .addTarget(prometheus.target(format='table', instant=true, expr='sum by(_1_instance, _0_nodename) (\nlabel_replace(\nlabel_replace(\n  node_uname_info{cluster=~"$cluster", job=~"$job", nodename=~"$instance"}\n    , "_1_instance", "$1", "instance", "(.*):.*")\n    , "_0_nodename","$1", "nodename", "(.*)")\n)'));

      local cpuCoresPanel =
        statPanel.new(
          title='CPU Cores',
          datasource='$datasource',
          unit='short',
        )
        .addTarget(prometheus.target('count(node_cpu_seconds_total{cluster=~"$cluster", job=~"$job", mode="system"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'))
        .addThreshold({ color: $._config.grafanaDashboards.color.blue, value: null });

      local memoryPanel =
        statPanel.new(
          title='Memory',
          datasource='$datasource',
          decimals=0,
          unit='bytes',
        )
        .addTarget(prometheus.target('sum(node_memory_MemTotal_bytes{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'))
        .addThreshold({ color: $._config.grafanaDashboards.color.blue, value: null });

      local cpuUtilPanel =
        gaugePanel.new(
          title='CPU Utilization',
          datasource='$datasource',
        )
        .addTarget(prometheus.target('round((1 - (avg(irate(node_cpu_seconds_total{cluster=~"$cluster", job=~"$job", mode="idle"}[5m]) * on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))))) * 100)'))
        .addThreshold({ color: $._config.grafanaDashboards.color.blue, value: null });

      local memUtilPanel =
        gaugePanel.new(
          title='Memory Utilization',
          datasource='$datasource',
          description='The percentage of the memory utilization is calculated by:\n```\n1 - (<memory available>/<memory total>)\n```',
          min=0,
          max=100,
        )
        .addTarget(prometheus.target('round((1 - (sum(node_memory_MemAvailable_bytes{cluster=~"$cluster", job=~"$job"} * on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) / sum(node_memory_MemTotal_bytes{cluster=~"$cluster", job=~"$job"}* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) )) * 100)'))
        .addThreshold({ color: $._config.grafanaDashboards.color.blue, value: null });

      local mostUtilDiskPanel =
        gaugePanel.new(
          title='Most Utilized Disk',
          datasource='$datasource',
          description='The percentage of the disk utilization is calculated using the fraction:\n```\n<space used>/(<space used> + <space free>)\n```\nThe value of <space free> is reduced by  5% of the available disk capacity, because   \nthe file system marks 5% of the available disk capacity as reserved. \nIf less than 5% is free, using the remaining reserved space requires root privileges.\nAny non-privileged users and processes are unable to write new data to the partition. See the list of explicitly ignored mount points and file systems [here](https://github.com/dNationCloud/kubernetes-monitoring-stack/blob/main/chart/values.yaml)',
          min=0,
          max=100,
        )
        .addTarget(prometheus.target('round(\nmax(\n(sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job"}) by (instance, device) - sum(node_filesystem_free_bytes{cluster=~"$cluster", job=~"$job"}) by (instance, device)) /\n(sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job"}) by (instance, device) - sum(node_filesystem_free_bytes{cluster=~"$cluster", job=~"$job"}) by (instance, device) +\nsum(node_filesystem_avail_bytes{cluster=~"$cluster", job=~"$job"}) by (instance, device))\n * 100 \n * on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))\n)\n)'))
        .addThreshold({ color: $._config.grafanaDashboards.color.blue, value: null });

      local networkErrPanel =
        gaugePanel.new(
          title='Network Errors',
          datasource='$datasource',
          unit='pps',
          min=0,
          max=100,
        )
        .addTarget(prometheus.target('sum(rate(node_network_transmit_errs_total{cluster=~"$cluster", job=~"$job", device!~"lo|veth.+|docker.+|flannel.+|cali.+|cbr.|cni.+|br.+"}[5m]) * on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) + \nsum(rate(node_network_receive_errs_total{cluster=~"$cluster", job=~"$job", device!~"lo|veth.+|docker.+|flannel.+|cali.+|cbr.|cni.+|br.+"}[5m]) * on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'))
        .addThreshold({ color: $._config.grafanaDashboards.color.blue, value: null });

      local cpuUtilGraphPanel =
        graphPanel.new(
          title='CPU Utilization',
          datasource='$datasource',
          format='percent',
          min=0,
          max=100,
        )
        .addTarget(prometheus.target(legendFormat='cpu  - {{nodename}}', expr='round((1 - (avg by (nodename) (irate(node_cpu_seconds_total{cluster=~"$cluster", job=~"$job", mode="idle"}[5m])\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))))) * 100)'));

      local loadAverageGraphPanel =
        graphPanel.new(
          title='Load Average',
          datasource='$datasource',
          fill=0,
          min=0,
        )
        .addSeriesOverride({ alias: '/logical cores/', color: '#C4162A', linewidth: 2 })
        .addTargets(
          [
            prometheus.target(legendFormat='1m load average {{nodename}}', expr='sum by (nodename) (node_load1{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
            prometheus.target(legendFormat='5m load average {{nodename}}', expr='sum by (nodename) (node_load5{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
            prometheus.target(legendFormat='15m load average {{nodename}}', expr='sum by (nodename) (node_load15{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
            prometheus.target(legendFormat='logical cores {{nodename}}', expr='count by (nodename) (node_cpu_seconds_total{cluster=~"$cluster", job=~"$job", mode="idle"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
          ]
        );

      local memUtilGraphPanel =
        graphPanel.new(
          title='Memory Utilization',
          description='The used memory is calculated by:\n```\n<memory total> - <memory available>\n```',
          datasource='$datasource',
          format='bytes',
          min=0,
        )
        .addSeriesOverride({ alias: '/total/', color: '#C4162A', fill: 0, linewidth: 2 })
        .addSeriesOverride({ alias: '/available/', hiddenSeries: true })
        .addSeriesOverride({ alias: '/buffers/', hiddenSeries: true })
        .addSeriesOverride({ alias: '/cached/', hiddenSeries: true })
        .addSeriesOverride({ alias: '/free/', hiddenSeries: true })
        .addTargets(
          [
            prometheus.target(legendFormat='memory used - {{nodename}}', expr='sum by (nodename) (node_memory_MemTotal_bytes{cluster=~"$cluster", job=~"$job"}* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) - sum by (nodename) (node_memory_MemAvailable_bytes{cluster=~"$cluster", job=~"$job"} * on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
            prometheus.target(legendFormat='memory available - {{nodename}}', expr='sum by (nodename) (node_memory_MemAvailable_bytes{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
            prometheus.target(legendFormat='memory buffers - {{nodename}}', expr='sum by (nodename) (node_memory_Buffers_bytes{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
            prometheus.target(legendFormat='memory cached - {{nodename}}', expr='sum by (nodename) (node_memory_Cached_bytes{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
            prometheus.target(legendFormat='memory free - {{nodename}}', expr='sum by (nodename) (node_memory_MemFree_bytes{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
            prometheus.target(legendFormat='memory total - {{nodename}}', expr='sum by (nodename) (node_memory_MemTotal_bytes{cluster=~"$cluster", job=~"$job"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
          ]
        );

      local diskUtilGraphPanel =
        graphPanel.new(
          title='Disk Utilization',
          description='The percentage of the disk utilization is calculated using the fraction:\n```\n<space used>/(<space used> + <space free>)\n```\nThe value of <space free> is reduced by  5% of the available disk capacity, because   \nthe file system marks 5% of the available disk capacity as reserved. \nIf less than 5% is free, using the remaining reserved space requires root privileges.\nAny non-privileged users and processes are unable to write new data to the partition. See the list of types of displayed disk filesystems [here](https://github.com/dNationCloud/kubernetes-monitoring/blob/main/jsonnet/dashboards/grafana-templates.libsonnet) and list of explicitly ignored mount points and file systems at node-exporter level [here](https://github.com/dNationCloud/kubernetes-monitoring-stack/blob/main/chart/values.yaml)',
          datasource='$datasource',
          formatY1='bytes',
          formatY2='percent',
          min=0,
        )
        .addSeriesOverride({ alias: '/size/', fill: 0, linewidth: 2 })
        .addSeriesOverride({ alias: '/available/', hiddenSeries: true })
        .addSeriesOverride({ alias: '/utilization/', yaxis: 2, lines: false, legend: false, pointradius: 0 })
        .addTargets(
          [
            prometheus.target(legendFormat='disk used {{device}} {{nodename}} {{mountpoint}}', expr='sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job", fstype=~"$diskfs"} * on(instance) group_left(nodename) (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) by (device, instance, nodename, mountpoint)  - sum(node_filesystem_free_bytes{cluster=~"$cluster", job=~"$job", fstype=~"$diskfs"} * on(instance) group_left(nodename) (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) by (device, instance, nodename, mountpoint)'),
            prometheus.target(legendFormat='disk size {{device}} {{nodename}} {{mountpoint}}', expr='sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job", fstype=~"$diskfs"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) by (device, instance, nodename, mountpoint)'),
            prometheus.target(legendFormat='disk available {{device}} {{nodename}} {{mountpoint}}', expr='sum(node_filesystem_avail_bytes{cluster=~"$cluster", job=~"$job", fstype=~"$diskfs"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) by (device, instance, nodename, mountpoint)'),
            prometheus.target(legendFormat='disk utilization {{device}} {{nodename}} {{mountpoint}}', expr='round((sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job", fstype=~"$diskfs"}) by (device, instance, nodename, mountpoint) - sum(node_filesystem_free_bytes{cluster=~"$cluster", job=~"$job", fstype=~"$diskfs"}) by (device, instance, nodename, mountpoint)) / (sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job", fstype=~"$diskfs"}) by (device, instance, nodename, mountpoint) - sum(node_filesystem_free_bytes{cluster=~"$cluster", job=~"$job", fstype=~"$diskfs"}) by (device, instance, nodename, mountpoint) + sum(node_filesystem_avail_bytes{cluster=~"$cluster", job=~"$job"}) by (device, instance, nodename, mountpoint)) * 100 * on(instance) group_left(nodename) (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
          ]
        ) { yaxes: std.mapWithIndex(function(i, item) if (i == 1) then item { show: false } else item, super.yaxes) };  // Hide second Y axis

      local virtualFilesystemsUtilGraphPanel =
        graphPanel.new(
          title='Disk Utilization (Virtual Filesystems)',
          description='The percentage of the virtual filesystems utilization is calculated using the fraction:\n```\n<space used>/(<space used> + <space free>)\n```\nThe value of <space free> is reduced by  5% of the available disk capacity, because   \nthe file system marks 5% of the available disk capacity as reserved. \nIf less than 5% is free, using the remaining reserved space requires root privileges.\nAny non-privileged users and processes are unable to write new data to the partition. See the list of explicitly ignored mount points and file systems at grafana level [here](https://github.com/dNationCloud/kubernetes-monitoring/blob/main/jsonnet/dashboards/grafana-templates.libsonnet) and at node-exporter level [here](https://github.com/dNationCloud/kubernetes-monitoring-stack/blob/main/chart/values.yaml)',
          datasource='$datasource',
          formatY1='bytes',
          formatY2='percent',
          min=0,
        )
        .addSeriesOverride({ alias: '/size/', fill: 0, linewidth: 2 })
        .addSeriesOverride({ alias: '/available/', hiddenSeries: true })
        .addSeriesOverride({ alias: '/utilization/', yaxis: 2, lines: false, legend: false, pointradius: 0 })
        .addTargets(
          [
            prometheus.target(legendFormat='disk used {{device}} {{nodename}} {{mountpoint}}', expr='sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job", fstype!~"$diskfs"} * on(instance) group_left(nodename) (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) by (device, instance, nodename)  - sum(node_filesystem_free_bytes{cluster=~"$cluster", job=~"$job", fstype!~"$diskfs"} * on(instance) group_left(nodename) (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) by (device, instance, nodename)'),
            prometheus.target(legendFormat='disk size {{device}} {{nodename}} {{mountpoint}}', expr='sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job", fstype!~"$diskfs"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) by (device, instance, nodename)'),
            prometheus.target(legendFormat='disk available {{device}} {{nodename}} {{mountpoint}}', expr='sum(node_filesystem_avail_bytes{cluster=~"$cluster", job=~"$job", fstype!~"$diskfs"}\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))) by (device, instance, nodename)'),
            prometheus.target(legendFormat='disk utilization {{device}} {{nodename}} {{mountpoint}}', expr='round((sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job", fstype!~"$diskfs"}) by (device, instance, nodename) - sum(node_filesystem_free_bytes{cluster=~"$cluster", job=~"$job", fstype!~"$diskfs"}) by (device, instance, nodename)) / (sum(node_filesystem_size_bytes{cluster=~"$cluster", job=~"$job", fstype!~"$diskfs"}) by (device, instance, nodename) - sum(node_filesystem_free_bytes{cluster=~"$cluster", job=~"$job", fstype!~"$diskfs"}) by (device, instance, nodename) + sum(node_filesystem_avail_bytes{cluster=~"$cluster", job=~"$job", fstype!~"$diskfs"}) by (device, instance, nodename)) * 100 * on(instance) group_left(nodename) (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename)))'),
          ]
        ) { yaxes: std.mapWithIndex(function(i, item) if (i == 1) then item { show: false } else item, super.yaxes) };  // Hide second Y axis

      local diskIOGraphPanel =
        graphPanel.new(
          title='Disk I/O',
          datasource='$datasource',
          formatY1='bytes',
          formatY2='s',
          fill=0,
        )
        .addSeriesOverride({ alias: '/read*|written*/', yaxis: 1 })
        .addSeriesOverride({ alias: '/io time*/', yaxis: 2 })
        .addTargets(
          [
            prometheus.target(legendFormat='read {{device}} {{nodename}}', expr='sum(rate(node_disk_read_bytes_total{cluster=~"$cluster", job=~"$job"}[5m])) by (instance)\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))'),
            prometheus.target(legendFormat='written {{device}} {{nodename}}', expr='sum(rate(node_disk_written_bytes_total{cluster=~"$cluster", job=~"$job"}[5m])) by (instance)\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))'),
            prometheus.target(legendFormat='io time {{device}} {{nodename}}', expr='sum(rate(node_disk_io_time_seconds_total{cluster=~"$cluster", job=~"$job"}[5m])) by (instance)\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))'),
          ]
        );

      local transRecGraphPanel =
        graphPanel.new(
          title='Transmit/Receive Errors',
          datasource='$datasource',
          format='pps',
          fill=0,
        )
        .addSeriesOverride({ alias: '/Rx_/', stack: 'B', transform: 'negative-Y' })
        .addSeriesOverride({ alias: '/Tx_/', stack: 'A' })
        .addTargets(
          [
            prometheus.target(legendFormat='Tx_{{device}} {{nodename}}', expr='rate(node_network_transmit_errs_total{cluster=~"$cluster", job=~"$job", device!~"lo|veth.+|docker.+|flannel.+|cali.+|cbr.|cni.+|br.+"}[5m])\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))'),
            prometheus.target(legendFormat='Rx_{{device}} {{nodename}}', expr='rate(node_network_receive_errs_total{cluster=~"$cluster", job=~"$job", device!~"lo|veth.+|docker.+|flannel.+|cali.+|cbr.|cni.+|br.+"}[5m])\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))'),
          ]
        );

      local netRecGraphPanel =
        graphPanel.new(
          title='Network Received',
          datasource='$datasource',
          format='bytes',
          fill=0,
          min=0,
        )
        .addTarget(prometheus.target(legendFormat='{{device}} {{nodename}}', expr='rate(node_network_receive_bytes_total{cluster=~"$cluster", job=~"$job", device!~"lo|veth.+|docker.+|flannel.+|cali.+|cbr.|cni.+|br.+"}[5m])\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))'));

      local netTransGraphPanel =
        graphPanel.new(
          title='Network Transmitted',
          datasource='$datasource',
          format='bytes',
          fill=0,
          min=0,
        )
        .addTarget(prometheus.target(legendFormat='{{device}} {{nodename}}', expr='rate(node_network_transmit_bytes_total{cluster=~"$cluster", job=~"$job", device!~"lo|veth.+|docker.+|flannel.+|cali.+|cbr.|cni.+|br.+"}[5m])\n* on(instance) group_left(nodename) \n   (avg(node_uname_info{cluster=~"$cluster", nodename=~"$instance"}) by (instance,nodename))'));

      dashboard.new(
        'Node Exporter',
        editable=$._config.grafanaDashboards.editable,
        graphTooltip=$._config.grafanaDashboards.tooltip,
        refresh=$._config.grafanaDashboards.refresh,
        time_from=$._config.grafanaDashboards.time_from,
        tags=$._config.grafanaDashboards.tags.k8sNodeExporter,
        uid=$._config.grafanaDashboards.ids.nodeExporter,
      )
      .addTemplates([
        $.grafanaTemplates.datasourceTemplate(),
        $.grafanaTemplates.clusterTemplate('label_values(node_uname_info, cluster)'),
        $.grafanaTemplates.jobTemplate('label_values(node_uname_info{cluster=~"$cluster"}, job)'),
        $.grafanaTemplates.instanceTemplate('label_values(node_uname_info{cluster=~"$cluster", job=~"$job"}, nodename)'),
        $.grafanaTemplates.diskFileSystemsTemplate(),
      ])
      .addPanels(
        [
          row.new('Overview') { gridPos: { x: 0, y: 0, w: 24, h: 1 } },
          upTimePanel { gridPos: { x: 0, y: 1, w: 4, h: 3 } },
          cpuUtilPanel { gridPos: { x: 4, y: 1, w: 5, h: 5 } },
          memUtilPanel { gridPos: { x: 9, y: 1, w: 5, h: 5 } },
          mostUtilDiskPanel { gridPos: { x: 14, y: 1, w: 5, h: 5 } },
          networkErrPanel { gridPos: { x: 19, y: 1, w: 5, h: 5 } },
          cpuCoresPanel { gridPos: { x: 0, y: 4, w: 2, h: 2 } },
          memoryPanel { gridPos: { x: 2, y: 4, w: 2, h: 2 } },
          ipTable { gridPos: { x: 0, y: 6, w: 24, h: 5 } },
          row.new('CPU Utilization / Load Average') { gridPos: { x: 0, y: 11, w: 24, h: 1 } },
          cpuUtilGraphPanel { gridPos: { x: 0, y: 12, w: 24, h: 7 }, tooltip+: { sort: 2 } },
          loadAverageGraphPanel { gridPos: { x: 0, y: 19, w: 24, h: 7 }, tooltip+: { sort: 2 } },
          row.new('Memory Utilization', collapse=true) { gridPos: { x: 0, y: 26, w: 24, h: 1 } }
          .addPanel(memUtilGraphPanel { tooltip+: { sort: 2 } }, { x: 0, y: 27, w: 24, h: 7 }),
          row.new('Disk Utilization', collapse=true) { gridPos: { x: 0, y: 28, w: 24, h: 1 } }
          .addPanel(diskUtilGraphPanel { tooltip+: { sort: 2 } }, { x: 0, y: 29, w: 24, h: 7 })
          .addPanel(virtualFilesystemsUtilGraphPanel { tooltip+: { sort: 2 } }, { x: 0, y: 36, w: 24, h: 7 })
          .addPanel(diskIOGraphPanel { tooltip+: { sort: 2 } }, { x: 0, y: 43, w: 24, h: 7 }),
          row.new('Network', collapse=true) { gridPos: { x: 0, y: 29, w: 24, h: 1 } }
          .addPanel(transRecGraphPanel { tooltip+: { sort: 2 } }, { x: 0, y: 30, w: 24, h: 7 })
          .addPanel(netRecGraphPanel { tooltip+: { sort: 2 } }, { x: 0, y: 37, w: 24, h: 7 })
          .addPanel(netTransGraphPanel { tooltip+: { sort: 2 } }, { x: 0, y: 44, w: 24, h: 7 }),
        ]
      ),
  },
}
