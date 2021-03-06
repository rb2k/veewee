Veewee::Session.declare({
  :cpu_count => '1',
  :memory_size=> '512',
  :disk_size => '10140',
  :disk_format => 'VDI',
  :hostiocache => 'off',
  :ioapic => 'on',
  :pae => 'on',
  :os_type_id => 'RedHat',
  :iso_file => "SL-62-i386-2012-02-06-boot.iso",
  :iso_src => "http://ftp.heanet.ie/pub/rsync.scientificlinux.org/6.2/i386/iso/SL-62-i386-2012-02-06-boot.iso",
  :iso_md5 => "c9f591724738634803f815f69339fc21",
  :iso_download_timeout => 1000,
  :boot_wait => "15",
  :boot_cmd_sequence => [ '<Tab> text ks=http://%IP%:%PORT%/ks.cfg<Enter>' ],
  :kickstart_port => "7122",
  :kickstart_timeout => 10000,
  :kickstart_file => "ks.cfg",
  :ssh_login_timeout => "10000",
  :ssh_user => "vagrant",
  :ssh_password => "vagrant",
  :ssh_key => "",
  :ssh_host_port => "7222",
  :ssh_guest_port => "22",
  :sudo_cmd => "echo '%p'|sudo -S sh '%f'",
  :shutdown_cmd => "/sbin/halt -h -p",
  :postinstall_files => [
    "base.sh",
    "puppet.sh",
    "chef.sh",
    "vagrant.sh",
    "virtualbox.sh",
    "cleanup.sh"
  ],
  :postinstall_timeout => 10000
})
