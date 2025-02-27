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

/* Application prometheus rules */

{
  prometheusRules+::
    local k8sApps = std.flattenArrays([
      cluster.apps
      for cluster in $._config.clusterMonitoring.clusters
      if std.objectHas(cluster, 'apps')
    ]);
    local k8sAppAlerts = std.set(
      std.flattenArrays([
        $.getTemplateAlerts($._config.templates.L1.k8sApps, app)
        for app in k8sApps
      ]), function(o) o.name
    );
    local hostApps = std.flattenArrays([
      host.apps
      for host in $._config.hostMonitoring.hosts
      if std.objectHas(host, 'apps')
    ]);
    local hostAppAlerts = std.set(
      std.flattenArrays([
        $.getTemplateAlerts($._config.templates.L1.hostApps, app)
        for app in hostApps
      ]), function(o) o.name
    );
    local vmApps = std.flattenArrays([
      vm.apps
      for cluster in $._config.clusterMonitoring.clusters
      if (std.objectHas(cluster, 'vms') && std.length(cluster.vms) > 0)
      for vm in cluster.vms
      if std.objectHas(vm, 'apps')
    ]);
    local vmAppAlerts = std.set(
      std.flattenArrays([
        $.getTemplateAlerts($._config.templates.L1.vmApps, app)
        for app in vmApps
      ]), function(o) o.name
    );
    if std.length(k8sAppAlerts) > 0 || std.length(hostAppAlerts) > 0 || std.length(vmAppAlerts) > 0 then
      {
        'apps.rules': {
          local alertGroupK8sApps = { alertgroup : $._config.prometheusRules.alertGroupClusterApp },
          local alertGroupHostApps = { alertgroup : $._config.prometheusRules.alertGroupHostApp },
          local alertGroupVmApps  = { alertgroup : $._config.prometheusRules.alertGroupClusterVMApp },
          groups: [
            $.newRuleGroup('k8sApps.rules')
            .addRules(
              // Add k8s cluster application rules
              std.flattenArrays(
                [
                  $.newAlertPair(
                    name=alert.name,
                    message=alert.message,
                    expr=alert.expr,
                    thresholds=alert.thresholds,
                    link=alert.link,
                    customLables=alertGroupK8sApps + alert.customLables,
                  )
                  for alert in k8sAppAlerts
                ]
              )
            ),
            $.newRuleGroup('hostApps.rules')
            .addRules(
              // Add host application rules
              std.flattenArrays(
                [
                  $.newAlertPair(
                    name=alert.name,
                    message=alert.message,
                    expr=alert.expr,
                    thresholds=alert.thresholds,
                    link=alert.link,
                    customLables=alertGroupHostApps + alert.customLables,
                  )
                  for alert in hostAppAlerts
                ]
              )
            ),
            $.newRuleGroup('vmApps.rules')
            .addRules(
              // Add vm application rules
              std.flattenArrays(
                [
                  $.newAlertPair(
                    name=alert.name,
                    message=alert.message,
                    expr=alert.expr,
                    thresholds=alert.thresholds,
                    link=alert.link,
                    customLables=alertGroupVmApps + alert.customLables,
                  )
                  for alert in vmAppAlerts
                ]
              )
            ),
          ],
        },
      }
    else
      {},
}
