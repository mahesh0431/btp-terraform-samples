# Discovery Center Mission: # Discovery Center mission: Keep the Core Clean Using SAP Build Apps with SAP S/4HANA (4024)

## Overview

This sample shows how to setup your SAP BTP account for the Discovery Center Mission - [Keep the Core Clean Using SAP Build Apps with SAP S/4HANA](https://discovery-center.cloud.sap/index.html#/missiondetail/4024/) for your Enterprise BTP Account.

The respective setup of a trial account is described in [SAP-samples/btp-terraform-samples/tree/main/released/discovery_center/mission_4024_trial/README.md](https://github.com/SAP-samples/btp-terraform-samples/tree/main/released/discovery_center/mission_4024_trial/README.md)

## Content of setup (step1)

The setup comprises the following resources:

- Creation of the SAP BTP subaccount
- Entitlements of services
- Subscriptions to applications
- Role collection assignments to users

After this a setup step2 you will configure trust to use only custom IdP for in step1 subscribed SAP Build Apps.

## Deploying the resources

Make sure that you are familiar with SAP BTP and know both the [Get Started with btp-terraform-samples](https://github.com/SAP-samples/btp-terraform-samples/blob/main/GET_STARTED.md) and the [Get Started with the Terraform Provider for BTP](https://developers.sap.com/tutorials/btp-terraform-get-started.html)

To deploy the resources you must:

### Setup Step1

1. Set your credentials as environment variables
   
   ```bash
   export BTP_USERNAME ='<Email address of your BTP user>'
   export BTP_PASSWORD ='<Password of your BTP user>'
   ```

2. Go into folder `step1` and change the variables in the `sample.tfvars` file to meet your requirements

   > The minimal set of parameters you should specify (besides user_email and password) is global account (i.e. its subdomain) and the used custom_idp and all user assignments
   
   > Keep the setting `create_tfvars_file_for_step2 = true` so that a `terraform.tfvars` file is created which contains your needed variables to execute setup `step2` without specifying them again in sample.tfvars there.

3. In folder `step1` you initialize your workspace:

   ```bash
   terraform init
   ```

4. You can check what Terraform plans to apply based on your configuration:

   ```bash
   terraform plan -var-file="sample.tfvars"
   ```

5. Apply your configuration to provision the resources:

   ```bash
   terraform apply -var-file="sample.tfvars"
   ```

6. Verify e.g., in BTP cockpit that a new subaccount with a SAP Build Apps and SAP Build Workzone subscriptions have been created.

### Setup Step2

7. Navigate into step2 directory and initialize your workspace there as well:

   ```bash
   terraform init
   ```
8. You can check what Terraform plans to apply based on your configuration:

   ```bash
   terraform plan -var-file="terraform.tfvars"
   ```

9. Apply your configuration to provision the resources:

   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```
10. Verify e.g., in BTP cockpit that after step2 the Security/Trust Configuration in your subaccount has defined only set a user login for Custom IAS tenant, so that SAP Build Apps opens the respective login page.

With this you have completed the quick account setup as described in the Discovery Center Mission - [Keep the Core Clean Using SAP Build Apps with SAP S/4HANA](https://discovery-center.cloud.sap/index.html#/missiondetail/4024/).

## In the end

You probably want to remove the assets after trying them out to avoid unnecessary costs. To do so execute the following command:

```bash
terraform destroy -var-file="terraform.tfvars"
```