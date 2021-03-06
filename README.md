# OCPUP

[![Build Status](https://travis-ci.org/dimaunx/ocpup.svg?branch=master)](https://travis-ci.org/dimaunx/ocpup)

This tool creates 3 OCP4 clusters on AWS and Openstack and connects them with submariner.

![deployment architecture](https://raw.githubusercontent.com/dimaunx/ocpup/master/docs/img/arch.jpg)

## Prerequisites

- [go 1.12] with [$GOPATH configured]
- [awscli]
- [Route53 public hosted zone]
- openshift-dev AWS account access or any other AWS account with near admin privileges.
- Upshift project access with the following [osp prerequisites].

## Build the tool

```bash
export GO111MODULE=on
go mod vendor
go install -mod vendor
```

The **ocpup** binary will be placed under **$GOPATH/bin/** directory.

## Configure awscli 

[Configure your AWS credentials] with awscli tool.

## Create config file

Create **ocpup.yaml** in the root on the repository. The tool will read **ocpup.yaml** file by default from the project root.
If the config is placed in other directory, pass the config file location to **ocpup** tool with **--config** flag.

```bash
ocpup create clusters --config /path/to/ocpup.yaml
``` 

Config file template that supports OSP and AWS installations:

```yaml
openshift:
  version: 4.2.8
clusters:
  - clusterName: cl1
    submarinerType: broker
    clusterType: public
    vpcCidr: 10.164.0.0/16
    podCidr: 10.244.0.0/14
    svcCidr: 100.94.0.0/16
    numMasters: 3
    numWorkers: 2
    numGateways: 1
    dnsDomain: devcluster.openshift.com
    platform:
      name: aws
      region: us-east-2
  - clusterName: cl2
    clusterType: public
    vpcCidr: 10.165.0.0/16
    podCidr: 10.248.0.0/14
    svcCidr: 100.95.0.0/16
    numMasters: 3
    numWorkers: 2
    numGateways: 1
    dnsDomain: devcluster.openshift.com
    platform:
      name: aws
      region: us-west-2
  - clusterName: cl3
    clusterType: private
    vpcCidr: 10.166.0.0/16
    podCidr: 10.252.0.0/14
    svcCidr: 100.96.0.0/16
    numMasters: 3
    numWorkers: 2
    numGateways: 1
    dnsDomain: devcluster.openshift.com
    platform:
      name: openstack
      region: regionOne
      externalNetwork: public
      computeFlavor: ci.m1.xlarge
helm:
  helmRepo:
    url: https://submariner-io.github.io/submariner-charts/charts
    name: submariner-latest
  broker:
    namespace: submariner-k8s-broker
  engine:
    namespace: submariner
    image:
      repository: quay.io/submariner/submariner
      tag: latest
  routeAgent:
    namespace: submariner
    image:
      repository: quay.io/submariner/submariner-route-agent
      tag: latest
operator:
  submarinerTag: latest
  submarinerRepo: quay.io/submariner
  operatorTag: 0.0.1
authentication:
  pullSecret: '{"auths"...}'
  sshKey: ssh-rsa xxx
  openstack:
    authUrl: https://upshift-project:13000/v3
    userName: myuser
    password: "mypassword"
    projectId: 8ce20565656frdfdf4655656
    projectName: my-upshift-project
    userDomainName: mydomain.com
```

Important config variables:

| Variable Name   | Description                                                                                                               |
|:--------------- |:--------------------------------------------------------------------------------------------------------------------------|
| version         | OCP version to install. The tools supports OCP [4.2.x] versions.                          |     
| dnsDomain       | AWS Route53 hosted zone domain name that you own. If not using openshift-dev account, please create a public hosted zone. | 
| pullSecret      | Security credentials from [Red Hat portal], please put this credentials in single quotes ''.                              | 
| sshKey          | SSH pub key from your workstation. Must have the corresponding private key.                                               |
| externalNetwork | OSP public network name.                                                                                                  |     
| computeFlavor   | OSP compute flavor for nodes.                                                                                             | 
| region          | OSP or AWS region name.                                                                                                   | 
| clusterType     | AWS clusters can be private or public, openstack clusters can be only private. Only one public cluster is required.       | 
| numGateways     | The number of worker nodes to tag as submariner gateway. Should be lower or equals to numWorkers.                         | 
| submarinerTag   | Submariner image tag for engine and route agent.                                                                          | 
| operatorTag     | Submariner operator tag.                                                                                                  | 
| submarinerRepo  | Submariner image repository name, submariner and submariner-route-agent will be added to the repo name by the operator.   | 


If one of the clusters is an Openstack cluster, the following parameters must be set under authentication/openstack:

| Variable Name   | Description                                                                                                               |
|:--------------- |:--------------------------------------------------------------------------------------------------------------------------|
| authUrl         | OSP authentication url.                                                                                                   | 
| userName        | OSP project username.                                                                                                     |
| password        | OSP project user password.                                                                                                     |
| projectId       | OSP project id.                                                                                                           |
| projectName     | OSP project name.                                                                                                         |
| userDomainName  | OSP user domain name.                                                                                                     |


## Create clusters that are ready for submariner deployment.

```bash
ocpup create clusters
```

The tool will create **.config** directory with the openshift install assets for each cluster.

The **.openshift-install.log** file in each cluster directory will contain a detailed log and cluster details.

The **bin** directory will contain all the required tools to interact with the clusters.

After the installation is complete, the export command for kubconfig files will be printed on the screen.

The example ocpup.yaml config will create the following setup:

| Cluster Name | Type                            | Machine CIDR   | Service CIDR  | Pods CIDR     | DNS Suffix                                |
|:-------------|:--------------------------------|:---------------|:--------------|:--------------|:------------------------------------------|
| cl1          | AWS Broker + Gateway IPI public | 10.164.0.0/16  | 100.94.0.0/16 | 10.244.0.0/14 | **username**-cl1.devcluster.openshift.com |
| cl2          | AWS Gateway IPI public          | 10.165.0.0/16  | 100.95.0.0/16 | 10.248.0.0/14 | **username**-cl2.devcluster.openshift.com |
| cl3          | OSP Gateway IPI private         | 10.166.0.0/16  | 100.96.0.0/16 | 10.252.0.0/14 | **username**-cl3.devcluster.openshift.com |

**username** is the current user that executes the tool.

The config must include at least two clusters and one of the clusters must have **submarinerType=broker** set. 
The broker cluster will also operate as a gateway cluster. 

## Deploy Submariner with operator:

After **ocpup create clusters** is complete.
```bash
ocpup deploy submariner
```

Reinstall submariner with values from config file, the image values will be read from ocpup.yaml.
```bash
ocpup deploy submariner --reinstall
```

## Deploy debug pods 

Deploy debug pods to all clusters: 
```bash
ocpup deploy netshoot
```

Deploy debug pods with host networking:
```bash
ocpup deploy netshoot --host-network
```

Deploy nginx-demo application to all clusters: 
```bash
ocpup deploy nginx-demo
```

## Destroy clusters:

```bash
ocpup destroy clusters
```

The deletion process takes up to 45 minutes, please be patient.

**Please remove your resources after you complete your testing.**

## VERY IMPORTANT

**UNDER NO CIRCUMSTANCES, DO NOT COMMIT ocpup.yaml FILE TO GIT!** 

<!--links-->
[go 1.12]: https://blog.golang.org/go1.12
[awscli]: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html
[Configure your AWS credentials]: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
[Red Hat portal]: https://cloud.redhat.com/openshift/install/aws/installer-provisioned
[Route53 public hosted zone]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/AboutHZWorkingWith.html
[$GOPATH configured]: https://github.com/golang/go/wiki/SettingGOPATH
[4.2.x]: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/
[osp prerequisites]: https://github.com/openshift/installer/blob/master/docs/user/openstack/README.md#openstack-requirements
