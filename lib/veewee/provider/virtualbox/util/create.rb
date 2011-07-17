require 'tempfile'

module Veewee
  module Provider
    module Virtualbox
      
      def create_vm

        #Verifying the os.id with the :os_type_id specified
        matchfound=false
        VirtualBox::Global.global.lib.virtualbox.guest_os_types.collect { |os|
          if @definition.os_type_id == os.id
            matchfound=true
          end
        }
        unless matchfound
          puts "The ostype: #{@definition.os_type_id} is not available in your Virtualbox version"
          exit
        end

        vm=VirtualBox::VM.find(@boxname)

        if (!vm.nil? && !(vm.powered_off?))
          puts "shutting down box"
          #We force it here, maybe vm.shutdown is cleaner
          vm.stop
        end     

        if !vm.nil? 
          puts "Box already exists"
          #vm.stop
          #vm.destroy
        else
          #TODO One day ruby-virtualbox will be able to handle this creation
          #Box does not exist, we can start to create it

          command="#{@vboxcmd} createvm --name '#{@boxname}' --ostype '#{@definition.os_type_id}' --register"

          #Exec and system stop the execution here
          Veewee::Util::Shell.execute("#{command}")

          # Modify the vm to enable or disable hw virtualization extensions
          vm_flags=%w{pagefusion acpi ioapic pae hpet hwvirtex hwvirtexcl nestedpaging largepages vtxvpid synthxcpu rtcuseutc}

          vm_flags.each do |vm_flag|
            if @definition.instance_variable_defined?("@#{vm_flag}")
              vm_flag_value=@definition.instance_variable_get(vm_flag.to_sym)
              puts "Setting VM Flag #{vm_flag} to #{vm_flag_value}"
              command="#{@vboxcmd} modifyvm #{@boxname} --#{vm_flag.to_s} #{vm_flag_value}"
              Veewee::Shell.execute("#{command}")
            end
          end


        end

        vm=VirtualBox::VM.find(@boxname)
        if vm.nil?
          puts "we tried to create a box or a box was here before"
          puts "but now it's gone"
          exit
        end

        #Set all params we know 
        vm.memory_size=@definition.memory_size.to_i
        vm.os_type_id=@definition.os_type_id
        vm.cpu_count=@definition.cpu_count.to_i
        vm.name=@boxname

        puts "Creating vm #{vm.name} : #{vm.memory_size}M - #{vm.cpu_count} CPU - #{vm.os_type_id}"
        #setting bootorder 
        vm.boot_order[0]=:hard_disk
        vm.boot_order[1]=:dvd
        vm.boot_order[2]=:null
        vm.boot_order[3]=:null
        vm.validate
        vm.save

      end


      def add_shared_folder
        
        command="#{@vboxcmd} sharedfolder add  '#{@boxname}' --name 'veewee-validation' --hostpath '#{File.expand_path(@environment.validation_dir)}' --automount"
        Veewee::Util::Shell.execute("#{command}")
        
      end
      
      def create_floppy
        # Todo Check for java
        # Todo check output of commands

        # Check for floppy
        unless @definition.floppy_files.nil?
          require 'tmpdir'
          temp_dir=Dir.tmpdir
          @definition.floppy_files.each do |filename|
            full_filename=full_filename=File.join(@environment.definition_dir,@boxname,filename)
            FileUtils.cp("#{full_filename}","#{temp_dir}")
          end
          javacode_dir=File.expand_path(File.join(__FILE__,'..','..','java'))
          floppy_file=File.join(@environment.definition_dir,@boxname,"virtualfloppy.vfd")
          command="java -jar #{javacode_dir}/dir2floppy.jar '#{temp_dir}' '#{floppy_file}'"
          puts "#{command}"
          Veewee::Util::Shell.execute("#{command}")

          # Create floppy controller
          command="#{@vboxcmd} storagectl '#{@boxname}' --name 'Floppy Controller' --add floppy"
          puts "#{command}"
          Veewee::Util::Shell.execute("#{command}")

          # Attach floppy to machine (the vfd extension is crucial to detect msdos type floppy)
          command="#{@vboxcmd} storageattach '#{@boxname}' --storagectl 'Floppy Controller' --port 0 --device 0 --type fdd --medium '#{floppy_file}'"
          puts "#{command}"
          Veewee::Util::Shell.execute("#{command}")   

        end
      end
      
      def create_disk
        #Now check the disks
        #Maybe one day we can use the name, now we have to check location
        #disk=VirtualBox::HardDrive.find(boxname)
        location=@boxname+"."+@definition.disk_format.downcase

        found=false       
        VirtualBox::HardDrive.all.each do |d|
          if !d.location.match(/#{location}/).nil?
            found=true
            break
          end
        end   

        if !found
          puts "Creating new harddrive of size #{@definition.disk_size.to_i} "

          #newdisk=VirtualBox::HardDrive.new
          #newdisk.format=@definition[:disk_format]
          #newdisk.logical_size=@definition[:disk_size].to_i

          #newdisk.location=location
          ##PDB: again problems with the virtualbox GEM
          ##VirtualBox::Global.global.max_vdi_size=1000000
          #newdisk.save

          command="#{@vboxcmd}  list  systemproperties|grep '^Default machine'|cut -d ':' -f 2|sed -e 's/^[ ]*//'"
          results=IO.popen("#{command}")
          place=results.gets.chop
          results.close

          command ="#{@vboxcmd} createhd --filename '#{place}/#{@boxname}/#{@boxname}.#{@definition.disk_format.downcase}' --size '#{@definition.disk_size.to_i}' --format #{@definition.disk_format.downcase} > /dev/null"
          puts "#{command}"
          Veewee::Util::Shell.execute("#{command}")

        end

      end

      def add_ide_controller
        #unless => "${vboxcmd} showvminfo '${vname}' | grep 'IDE Controller' "
        command ="#{@vboxcmd} storagectl '#{@boxname}' --name 'IDE Controller' --add ide"
        Veewee::Util::Shell.execute("#{command}")
      end

      def add_sata_controller
        #unless => "${vboxcmd} showvminfo '${vname}' | grep 'SATA Controller' ";
        command ="#{@vboxcmd} storagectl '#{@boxname}' --name 'SATA Controller' --add sata --hostiocache #{@definition.hostiocache}"
        Veewee::Util::Shell.execute("#{command}")
      end


      def attach_disk
        location=@boxname+"."+@definition.disk_format.downcase

        command="#{@vboxcmd}  list  systemproperties|grep '^Default machine'|cut -d ':' -f 2|sed -e 's/^[ ]*//'"
        results=IO.popen("#{command}")
        place=results.gets.chop
        results.close

        location="#{place}/#{@boxname}/"+location
        puts "Attaching disk: #{location}"

        #command => "${vboxcmd} storageattach '${vname}' --storagectl 'SATA Controller' --port 0 --device 0 --type hdd --medium '${vname}.vdi'",
        command ="#{@vboxcmd} storageattach '#{@boxname}' --storagectl 'SATA Controller' --port 0 --device 0 --type hdd --medium '#{location}'"
        Veewee::Util::Shell.execute("#{command}")

      end

      def mount_isofile
        full_iso_file=File.join(@environment.iso_dir,@definition.iso_file)
        puts "Mounting cdrom: #{full_iso_file}"
        #command => "${vboxcmd} storageattach '${vname}' --storagectl 'IDE Controller' --type dvddrive --port 1 --device 0 --medium '${isodst}' ";
        command ="#{@vboxcmd} storageattach '#{@boxname}' --storagectl 'IDE Controller' --type dvddrive --port 1 --device 0 --medium '#{full_iso_file}'"
        Veewee::Util::Shell.execute("#{command}")
      end


    end #End Module
  end #End Module
end #End Module
