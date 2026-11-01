> **Note:** this guide describes the 2020 (Plone 5.2) version of Plone in a Box™. Current boxes run Plone 6 on ports 80/443 (not 8080) with a generated admin password instead of `admin`/`admin`; see the [current setup guide](../setup-guide.md).

# How to Setup Your Plone in a Box™ (Ploneconf2020)
For the presentation “Your Plone [Intranet] in a Box™” by Kim Nguyen, https://2020.ploneconf.org/talks/your-plone-intranet-in-a-boxtm/view

We will:

- compare cloud providers you can use to create your Plone [Intranet] in a Box™ (Amazon AWS, Linode, DigitalOcean)
- guide you through the super quick process of setting up a brand new Plone [Intranet] in a Box™ on a shiny new virtual machine running in the cloud
- discuss how to make your new Plone [Intranet] in a Box™ enterprise-ready
# Several Ways to Install Plone

If you want to try a demo Plone site, a good starting point is to use https://demo.plone.org. Other Plone demo sites are available at https://plone.org/what-is-plone/plone/try-plone

However, if you want to take Plone for a longer test drive and see how it works with your own content and how you can collaborate on a Plone site with colleagues, you need to install it on a computer of your own.

Plone can be installed several different ways. You can run it natively on macOS, Linux, Unix, and Windows computers, and you can run it inside containers such as Vagrant and Docker. 

You can install Plone on a computer of your own. Most commonly, however, Plone is run in a virtual machine hosted by cloud providers such as Amazon AWS, Linode, and DigitalOcean.

Your starting point for installing Plone is typically https://plone.org/download, where you would use the Plone unified installer, the simple Plone buildout, the Plone Docker, and some newer methods that use `pip install`.

But while these methods are great for developers, they’re less good for non-technical users who want to try Plone on a server of their own. This is what Plone in a Box™ tries to address.


# Plone in a Box™, for Non-Technical Users

Plone in a Box™ is a method for non-programmers to quickly and easily set up a server running Plone.

The server will run the latest supported release of Plone, currently 5.2.2.

The installation of Plone includes several trusted add-ons:

- collective.documentviewer
- collective.easyform
- pas.plugins.ldap
- eea.facetednavigation
- plone.app.mosaic
- collective.taxonomy
- collective.lineage

Please note: the Plone installation is not configured to send out email, but that can be added relatively easily.

# Securing your Plone in a Box™ 

A note of caution: Plone in a Box™ is not a secure, production-ready server. 

If you want to secure your Plone in a Box™, you should do at least the following:

- change the `admin` password and set it to something difficult to guess (please use a password manager that generates long, complex passwords!)
- set up a firewall
- enable backups
- disable root login
- disable password logins (allow only SSH key logins)
- enable log rotation
- set up intrusion and alert monitoring
- install an SSL certificate, require `https` (secure) browsing only, and disable `http` browsing on ports 80 and 8080

There are many Plone service providers who would be happy to help you do the above. Please see the list of Plone providers at https://plone.org/providers.

Future updates to Plone in a Box™ are planned. These updates will include more security configuration as part of the default installation and will update existing installations to add more security. 


# Choosing a Cloud Provider

We have chosen to make Plone in a Box™ available first on Amazon AWS and on Linode.

Amazon AWS (https://aws.amazon.com) is the most established and arguably the largest cloud provider, with the most complete feature set. Large organizations and a surprising number of commonly used apps, websites, and services are deployed using Amazon AWS. Running a system on AWS can be expensive. You can expect your AWS Plone in a Box™ to cost about $20 per month.

Linode (https://linode.com) has a smaller feature set but is simpler and less expensive to use. You can expect your Linode Plone in a Box™ to cost about $5 per month.

Support for Plone in a Box™ on DigitalOcean (https://digitalocean.com) is coming soon. DigitalOcean is similar to Linode but has a more established “app marketplace” for one-button installation of commonly used software. You can expect your DigitalOcean Plone in a Box™ to cost about $5 per month.

# Plone in a Box™ on Amazon AWS

Plone in a Box™ is a preconfigured Amazon AWS machine image that you can use with the AWS free service tier. 


## Create an AWS account

You will have to sign up for an AWS account if you don’t already have one. 
Go to https://aws.amazon.com and click the orange button “Create an AWS Account” in top right corner

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915628344_image.png)

        AWS accounts include 12 months of Free Tier access; see https://aws.amazon.com/free.
        
        You will have to enter a credit card which will be changed a temporary $1 fee that will be removed after 3-5 days.
        
        Choose the Basic Support Plan
![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915593630_image.png)


Sign into the Console 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915564067_image.png)


Use the default choice “Root user” and enter the email address you just used to create your AWS account 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915526197_image.png)


Enter your password
You are at the AWS Console 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915491588_image.png)

## Create a new EC2 instance using an AMI

Click on the Services drop down menu in the top black bar

Choose “EC2” 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915451501_image.png)


Click the orange button “Launch an Instance” at the bottom 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915373179_image.png)


You will see an AMI search page 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915335307_image.png)


*** IMPORTANT *** Set the region to `us-east-1`, or `N. Virginia` 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591807274401_image.png)


Search for the AMI (Amazon Machine Image) named `Plone In A Box` 
You will find it in the Community AMIs. 

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607392256091_image.png)



![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607392210241_image.png)


Click the blue Select button. 

Leave the default `t2.micro` selection, which is available as part of the AWS free tier. 

**Note**: if you are ok not using the free tier, or you have already used up all of your AWS free tier, you can use the `t3.micro`  or `t3a.micro` types and actually save money, relative to the cost of running a `t2.micro`. See https://ec2instances.info/?cost_duration=monthly

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915295169_image.png)


Click “Next: Configure Instance Details” in the bottom right corner 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915260867_image.png)


Leave everything else as is, and click “Next: Add Storage” in the bottom right corner 

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607392599060_image.png)


Leave as is, and click “Next: Add Tags” in the bottom right corner 

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607392687746_image.png)


Leave as is, and click “Next: Configure Security Group” in the bottom right corner 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915105738_image.png)


Click the grey “Add Rule” button and enter “8080” in the Port Range column 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591821438799_image.png)


Leave everything else as is, and click the blue button “Review and Launch” 

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607392791895_image.png)


Click the blue “Launch” button 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591811199636_image.png)


If you have an existing key pair, choose it; otherwise, choose “Create a new key pair” 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591811228555_image.png)


Enter a new key pair name, e.g. “MyNewKeyPair”
Press the grey “Download Key Pair” button 

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607392878814_image.png)


This will download a file called `MyNewKeyPair``.pem` to your computer; you will need it to `ssh` into the instance.

Press the blue Launch Instances button.

On the Launch Status page, click on the link to your new instance.

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591811452914_image.png)

## View your Plone site

You will need to wait up to 5 minutes for your new server to start up and for it to begin running Plone.

On the EC2 Instances page, you will find the IP address of your new instance in the bottom pane, in the right column. 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591915028488_image.png)


Place your mouse just to the right of that IP address; a small icon will appear. Click on it to copy the IP address to your clipboard. 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591821755863_image.png)


Open a new browser tab and paste the IP address into the address bar, with `:8080` appended (a colon immediately followed by the port number 8080, the port that Plone listens on by default), and press Enter

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591821852103_image.png)


You should see the Plone container page 

![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591914983559_image.png)

    - Click on the blue button “View your Plone site” 
![](https://paper-attachments.dropbox.com/s_DB4A6F84233F8A881158E511599BD7A89CEAD59196F399DD8113B8690678413C_1591914951297_image.png)


To log in, use the “Log In” link at the top of the front page, and enter:

    `admin` (Login Name)
    `admin` (Password)


# Plone in a Box™ on Linode

Plone in a Box™ is available as a Community StackScript that you use to launch a Linode. 


## Create a Linode account

You will have to sign up for an account if you don’t already have one. 

Go to https://linode.com and click the green “Sign Up” button in the top right corner.

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607559895434_Screen+Shot+2020-12-09+at+6.22.34+PM.png)

## Create a new Linode using a StackScript

Once you are logged in to your account, click “StackScripts” in the left bar

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607559969983_Screen+Shot+2020-12-09+at+4.37.39+PM.png)


Click on Community StackScripts:

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560009781_Screen+Shot+2020-12-09+at+4.38.03+PM.png)


In the search box, enter “Plone in a box” then wait a few seconds or press Enter:

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560029093_Screen+Shot+2020-12-09+at+4.38.10+PM.png)


Click the three blue dots at the right and choose “Deploy New Linode”:

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560093987_Screen+Shot+2020-12-09+at+4.38.21+PM.png)


Leave the default choice of Image (Ubuntu 20.04 LTS).

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560175141_Screen+Shot+2020-12-09+at+4.38.36+PM.png)


Choose a region in which you’d like your new Linode to be hosted. 

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560185200_Screen+Shot+2020-12-09+at+4.38.44+PM.png)


Choose a Linode Plan. The “Nanode 1GB” will run a Plone site that is good for sites with only a few simultaneously logged-in users.

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560274978_Screen+Shot+2020-12-09+at+4.38.56+PM.png)


You can set a Linode Label, or name, for your Linode. 

You can add tags, which let you search for and find your Linode more easily if you have many of them.

Set a root password. 


![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560296112_Screen+Shot+2020-12-09+at+4.39.05+PM.png)


You should add an SSH key if you have one. SSH is a more secure way of logging into your Linode than relying on password logins.

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560453450_Screen+Shot+2020-12-09+at+4.39.25+PM.png)


You can enable automatic backups for your Linode. Backups are vital if you will be relying on your Linode and its Plone site.

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560571894_Screen+Shot+2020-12-09+at+4.40.16+PM.png)


Press the blue Create button to create your Linode. 

You will see a status bar indicating that your Linode is being created (“provisioned”).

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560596680_Screen+Shot+2020-12-09+at+4.40.26+PM.png)


Note the IP address of your Linode.

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560855403_Screen+Shot+2020-12-09+at+4.45.18+PM+copy.png)


The Activity tab shows any boot, shutdown, or other major events for your Linode.

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560650065_Screen+Shot+2020-12-09+at+5.39.51+PM.png)


Expect a Nanode Linode to take only a minute or two to be provisioned, but for Plone’s installation on the server to take another 10 minutes or so. 

Wait 10-12 minutes, then open a new browser tab and paste the IP address of your Linode into the address bar, with `:8080` appended (a colon immediately followed by the port number 8080, the port that Plone listens on by default), and press Enter.

Depending on your browser, you may find it helpful to prefix the IP address with `http://`. Some browsers, depending on their settings, may warn you about visiting a website using the `http:` (unencrypted) protocol, but it’s safe to proceed.


![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607560959459_image.png)

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607561079259_Screen+Shot+2020-12-09+at+6.14.58+PM.png)


Click the blue “Create a new Plone site” button.

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607561153002_Screen+Shot+2020-12-09+at+6.17.41+PM.png)


Log in using the user name `admin` and the password `admin`.

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607561180249_Screen+Shot+2020-12-09+at+6.18.01+PM.png)


You can give your new Plone site a path identifier (this is what will appear in the web address), a title, the default language, and the default timezone for the site. 


![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607561202315_Screen+Shot+2020-12-09+at+6.18.11+PM.png)


Press the blue Create Plone Site button.

![](https://paper-attachments.dropbox.com/s_0B4DA4875154F3335237A5ECAFB2FADB22C231445E4AF0B3FF070DA08AE04AB5_1607561318967_Screen+Shot+2020-12-09+at+6.18.30+PM.png)


Congratulations! You’ve created a new Plone site on your very own Linode.





# Plone in a Box™ on DigitalOcean

Plone in a Box™ on DigitalOcean is coming soon! We are in the process of obtaining an account on the DigitalOcean App Marketplace.



