data "template_file" "myuserdata" {
  template = "${file("${path.cwd}/myuserdata.tpl")}"
}