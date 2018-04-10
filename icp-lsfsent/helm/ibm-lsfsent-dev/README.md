# IBM Spectrum LSF Community Edition

[IBM Spectrum LSF Community Edition](https://www.ibm.com/support/knowledgecenter/en/SSWRJV_10.1.0/lsf_offering/lsfce10.1_quick_start.html) is a no-charge edition of IBM Spectrum LSF workload management platform.

## Introduction

This chart is not intended for separate use. It
is intended for use with IBM Cloud Private product. IBM Cloud Private is a, Kubernetes based, container management solution.  IBM Spectrum LSF Community Edition is a no-charge edition of IBM Spectrum LSF workload management platform.  IBM Spectrum LSF is a powerful workload management system for distributed computing environments. IBM Spectrum LSF provides a comprehensive set of intelligent, policy-driven scheduling features that enable you to utilize all of your compute infrastructure resources and ensure optimal application performance.

## Prerequisites
- A persistant volume is required for this chart.  It should be at least 1GByte and have ReadWriteMany access.  Prior to deploying the chart create the persistent volume.

- Optional:  Typically the cluster will run applications and access data that resides outside of the cluster.  To mount application binaries, or data directories in the cluster set the appropriate "data" or "application" variables.  The data or application directories are assumed to be available through existing persistant volume claims.  For data directory set Storage.connectDataPVC to true, and set the Storage.datapvc to the name of the persistant volume claim with access to the data.  For application directory access set Storage.connectAppPVC to true, and set the Storage.apppvc to the name of the persistant volume claim with access to the applications.  

- IBM Spectrum LSF Community Edition is restricted to 2 CPU sockets.  If IBM Cloud Private has been installed on virtual machines, they should  be limited to 2 CPUs.

- A nodeSelector is used limit the machines to run on.  Tag the machines that have 2 CPU sockets by running:
```bash
$ kubectl get nodes --show-labels
$ kubectl label nodes {Name of node from above command} deploy_lsf=true
```


## Installing the Chart

To install the chart with optional application volume mounted:

```bash
$ helm install --set Storage.connectAppPVC=true,Storage.apppvc={APP_PVC_NAME} ibm-lsfsent-dev
```

The command deploys ibm-lsfsent-dev. The GUI can be accessed from IBM Cloud Private GUI by navigating to the Workloads, Services, and searching for the LSF CE Cluster and click on the Node port. 

The LSF Community Edition can have up to 10 nodes in the cluster, 1 master and 9 workers.  Set the lsf.worker.replicas to control the number of worker nodes.

The default login/password for the web GUI is lsfadmin / lsfadmin
The URL can be determined by running:
```bash
$ export NODE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services `my-release`)
$  export NODE_IP=$(kubectl get --namespace default -o jsonpath="{.spec.clusterIP}" services `my-release`)
$  echo http://$NODE_IP:$NODE_PORT
```

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```bash
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.  Data written to the persistant volume claim will remain including any jobs submitted to the system.

## Configuration
The following table lists the configurable parameters of the ibm-lsfsent-dev and lsf-slave charts and there default values.

| Parameter                     | Description                                     | Default                                |
| --------------------------    | ---------------------------------------------   | -------------------------------------- |
| `lsf.worker.replicas`     | The number of workers in the cluster.  Max 9    | `1`                                    | 
| `lsf.worker.cpu`          | The CPU resource to assign to the slave         | `200m`                                    | 
| `lsf.worker.memory`       | The Memory resources to assign to the slave     | `200Mi`                                      | 
| `lsf.image.repository`    | `LSFCE` image repository                        | `ibmcom/lsfce`                         | 
| `lsf.image.tag`           | `LSFCE` image repository tag                    | `10.2.0`                               | 
| `lsf.image.pullPolicy`    | The policy for processing missing images        | `IfNotPresent`                         | 
| `Storage.connectDataPVC`  | Flag to control if we should connect a data PVC | `false`                           | 
| `Storage.datapvc`         | Name of an existing PersistentVolumeClaim holding data | `mydatapvc`                           | 
| `Storage.connectAppPVC`   | Flag to control if we should connect an application PVC | `false`                           | 
| `Storage.apppvc`          | Name of an existing PersistentVolumeClaim holding applications | `myapppvc`                           | 
| `mariadb.image.repository` | `mariadb` image repository                      | `ibmcom/mariadb`                       | 
| `mariadb.image.tag`       | `mariadb` image repository tag                  | `10.1.16`                              | 
| `mariadb.password`        | The default password for the database           | `passw0rd`                             | 

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

## Persistence

The chart requires an existing PersistentVolume to hold the clusters configuration and user data.

- The PersistentVolume can be created either by filling in the appropriate values in the IBM Cloud Private GUI, or using the json below.  Note the storage size, server IP, and path to the NFS export have to be set.
```bash
{
  "kind": "PersistentVolume",
  "apiVersion": "v1",
  "metadata": {
    "name": "lsf",
    "labels": {}
  },
  "spec": {
    "capacity": {
      "storage": "50Gi"
    },
    "accessModes": [
      "ReadWriteMany"
    ],
    "persistentVolumeReclaimPolicy": "Recycle",
    "nfs": {"server": "{IP Address of NFS Server}", "path": "{NFS Export Path}"}
  }
}
```

- Optionally PersistentVolumeClaims can be used to hold data and applications that will be used by the cluster.  This will allow the applications and data to be shared.  First create the PersistentVolume.  Use a label to identify this as either the data or application volume.  Then create the PersistentVolumeClaim using the label name and value from the PersistentVolume.  Use the Storage.connectDataPVC or Storage.connectAppPVC  flags to indicate that the data and or application PersistentVolumeClaims should be used, and specify there names in Storage.datapvc and or Storage.apppvc.  

